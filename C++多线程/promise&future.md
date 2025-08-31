# std::promise & std::future

C++ 标准库中的 `std::promise` 和 `std::future` 是现代 C++ 并发编程中非常重要的工具，用于在不同线程之间安全、方便地传递数据。

## 核心思想：异步通信频道

想象一下，`std::promise` 和 `std::future` 共同构成了一个一次性的、单向的线程间通信频道。

- **`std::promise`**：可以看作是这个频道的**写入端**（或“生产者”）。它 *承诺* 在未来的某个时刻会提供一个值。
- **`std::future`**：可以看作是这个频道的**读取端**（或“消费者”）。它代表一个 *未来* 才会出现的结果。

一个线程持有 `std::promise` 对象，负责计算或生成结果，然后将结果放入 `promise`。另一个线程持有与该 `promise` 关联的 `std::future` 对象，它可以通过 `future` 等待并最终获取这个结果。

## 一个生活中的比喻

为了更好地理解，我们用一个“咖啡店叫号”的比喻：

1. **你去点单（创建 Promise 和 Future）**
   - 你（主线程）点了一杯咖啡。
   - 咖啡师给了你一个**叫号器（`std::future`）**。
   - 咖啡师自己保留了制作咖啡的**承诺（`std::promise`）**，这个承诺与你的叫号器是配对的。
2. **咖啡师制作咖啡（生产者线程工作）**
   - 咖啡师（工作线程）在后台努力制作你的咖啡。这可能需要一些时间。
   - 制作完成后，咖啡师通过内部系统按下按钮，**履行承诺（调用 `promise.set_value()`）**，通知你的叫号器。
3. **你等待并取走咖啡（消费者线程获取结果）**
   - 你拿着叫号器（`future`）可以去做别的事情。
   - 当你想要咖啡时，你就看着叫号器（**调用 `future.get()`**）。
   - 如果叫号器还没响（值还没准备好），你就只能在那里**阻塞等待**。
   - 一旦叫号器响了（值已准备好），你就可以凭它取走你的咖啡（`get()` 方法返回结果）。
   - 这个叫号器用过一次后就作废了（`get()` 只能调用一次）。

如果制作过程中出了问题（比如咖啡豆用完了），咖啡师可以通知系统一个**异常（`promise.set_exception()`）**，你的叫号器也会收到这个异常信息（`future.get()` 会抛出该异常）。

## `std::promise<T>` 详解

`std::promise` 是一个模板类，其中 `T` 是你承诺要传递的数据类型。

**主要成员函数:**

- **`get_future()`**:
  - 获取与此 `promise` 相关联的 `std::future` 对象。
  - **注意**：对于一个 `promise` 对象，这个函数只能被调用一次。一旦 `future` 被获取，它们就绑定在了一起。
- **`set_value(const T& value)`**:
  - 履行承诺，将结果 `value` 存入共享状态中。
  - 这会使得关联的 `future` 变为“就绪”（ready）状态。
  - 正在等待 `future` 的线程会被唤醒。
- **`set_exception(std::exception_ptr p)`**:
  - 当无法生成值时，可以通过这个函数存入一个异常。
  - 这同样会使 `future` 变为“就绪”状态。

## `std::future<T>` 详解

`std::future` 同样是一个模板类，`T` 必须与 `promise` 的类型一致。它提供了访问异步操作结果的机制。

**主要成员函数:**

- **`get()`**:
  - 等待与 `promise` 关联的共享状态变为“就绪”。
  - 如果共享状态已经就绪，它会立即返回结果。
  - 如果尚未就绪，**当前线程将被阻塞**，直到结果被设置。
  - 如果 `promise` 中设置的是一个值，`get()` 会返回值。
  - 如果 `promise` 中设置的是一个异常，`get()` 会重新抛出该异常。
  - **注意**：`get()` 只能被调用一次。调用后，`future` 对象本身会变为无效状态 (`valid() == false`)。
- **`wait()`**:
  - 阻塞当前线程，直到 `future` 就绪，但不获取值。可以多次调用。
- **`wait_for(duration)`**:
  - 等待一段时间，看 `future` 是否就绪。它不会一直阻塞，超时后就会返回。返回一个 `std::future_status` 枚举（`ready`, `timeout`, `deferred`）。
- **`valid()`**:
  - 检查 `future` 对象是否与一个有效的共享状态相关联。一个 `future` 在被默认构造、被移动（move）或其 `get()` 方法被调用后会变为无效。

## 代码示例

下面是一个简单的例子，主线程创建一个工作线程来执行一个耗时计算，并使用 `promise` 和 `future` 来取回计算结果。

```cpp
#include <iostream>
#include <thread>
#include <future>
#include <chrono>

// 一个耗时的计算函数
void heavy_calculation(std::promise<int> prom) {
    std::cout << "Worker thread is starting the calculation..." << std::endl;
    // 模拟耗时操作
    std::this_thread::sleep_for(std::chrono::seconds(3));
    int result = 42;
    std::cout << "Worker thread has finished. Setting the value." << std::endl;
    
    // 履行承诺，将结果放入 promise
    prom.set_value(result); 
}

int main() {
    // 1. 创建一个 promise 对象
    std::promise<int> p;

    // 2. 从 promise 获取 future 对象（只能获取一次）
    std::future<int> f = p.get_future();

    // 3. 创建工作线程，并将 promise 的所有权转移(move)给它
    //    std::promise 不能被拷贝，只能被移动
    std::thread worker_thread(heavy_calculation, std::move(p));

    // 主线程可以做一些其他的事情...
    std::cout << "Main thread is doing other work while waiting for the result..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // 4. 当主线程需要结果时，调用 future::get()
    std::cout << "Main thread is now asking for the result." << std::endl;
    
    // get() 会阻塞，直到 worker_thread 调用 set_value()
    int result = f.get(); 

    std::cout << "The calculated result is: " << result << std::endl;

    // 等待工作线程结束
    worker_thread.join();

    return 0;
}
```

**代码分析：**

1. 在 `main` 函数中，我们创建了一个 `std::promise<int>`，承诺未来会有一个 `int` 类型的结果。
2. 我们立即通过 `p.get_future()` 获取了对应的 `std::future<int>` 对象 `f`。
3. 我们创建了一个新线程 `worker_thread`，并将 `p` **移动** (`std::move(p)`) 到线程的入口函数 `heavy_calculation` 中。这是因为 `promise` 不支持拷贝，它代表了对共享状态的唯一所有权。
4. 主线程可以继续执行自己的任务。
5. 当主线程需要结果时，它调用 `f.get()`。此时，由于工作线程还在 `sleep`，`get()` 会阻塞主线程。
6. 3秒后，工作线程完成计算，调用 `prom.set_value(42)`。这个操作会使 `f` 的状态变为“就绪”，并唤醒正在等待的主线程。
7. 主线程从 `get()` 返回，并获得结果 `42`，然后打印出来。

## 非阻塞用法

在上述代码中，一旦主线程调用了 `future.get()`，它就会**立即阻塞（Block）**，直到 `promise` 准备好结果为止。

我们可以将“阻塞”理解为**“暂停并等待”**。

这正是 `std::future` 的核心设计机制之一：它提供了一种同步线程的方式。当一个线程（比如主线程）需要另一个线程（工作线程）的计算结果时，它就调用 `get()`，然后这个线程就会被操作系统挂起，不再消耗 CPU 时间，直到它被唤醒。

### 详细解释：

1. **调用 `get()` 的瞬间**：
   - 系统会检查与 `future` 关联的共享状态是否为“就绪”（ready）。
   - **如果尚未就绪**（即 `promise` 还没有调用 `set_value()` 或 `set_exception()`），那么调用 `get()` 的线程（主线程）会**立即进入等待状态**。它会交出 CPU 的控制权，暂停在这里，不会执行 `get()` 后面的任何代码。
   - **如果已经就绪**，那么 `get()` 会立即返回结果，主线程继续执行后面的代码，不会有任何等待。
2. **何时解除阻塞**：
   - 当持有 `promise` 的工作线程调用了 `set_value()` 或 `set_exception()` 后，共享状态变为“就绪”。
   - 这个事件会通知操作系统，唤醒正在等待这个 `future` 的主线程。
   - 主线程被唤醒后，`get()` 函数才能成功返回（返回值或抛出异常），然后主线程继续执行它后面的代码。

### 生活中的比喻：

回到之前的咖啡店比喻：

- 调用 `future.get()` 就好比你走到取餐口，**死死地盯着显示屏等你的号码**。在你的号码出现之前，你不会离开取餐口，不会去看手机，也不会和朋友聊天。你就站在那里，什么也不干，一直等。这就是**阻塞**。

### 如果我不想让主线程一直等待怎么办？

这是一个非常实际的问题。在很多应用中，尤其是有图形用户界面（GUI）的程序，主线程（UI 线程）是绝对不能被长时间阻塞的，否则整个程序会看起来像“卡死了”一样。

为此，`std::future` 提供了**非阻塞**的等待方式：

**`wait_for()`** 函数

这个函数允许你“检查一下”结果是否好了，但只等待一个指定的时间。

- `std::future_status status = f.wait_for(std::chrono::seconds(0));`

这行代码会立即检查 `future` 的状态，而不等待。`status` 会是以下三种情况之一：

- **`std::future_status::ready`**: 结果已经准备好了！你可以安全地调用 `f.get()` 并且它会立刻返回。
- **`std::future_status::timeout`**: 等待超时了（在这个例子里是0秒），结果还没好。
- **`std::future_status::deferred`**: （这与 `std::async` 的延迟执行策略有关，这里可以暂时忽略）。

### 代码示例

```cpp
#include <iostream>
#include <thread>
#include <future>
#include <chrono>

void long_running_task(std::promise<int> prom) {
    std::this_thread::sleep_for(std::chrono::seconds(5));
    prom.set_value(100);
}

int main() {
    std::promise<int> p;
    std::future<int> f = p.get_future();
    std::thread worker(long_running_task, std::move(p));

    std::cout << "Main thread started. Checking for result periodically." << std::endl;

    // 主线程不会阻塞，而是周期性地检查结果
    while (true) {
        // 等待1秒，看结果好了没有
        auto status = f.wait_for(std::chrono::seconds(1));
        
        if (status == std::future_status::ready) {
            std::cout << "Result is ready!" << std::endl;
            break; // 退出循环去获取结果
        } else {
            std::cout << "Result not ready yet. Main thread continues to do other work..." << std::endl;
        }
    }

    // 此时我们知道结果肯定好了，调用 get() 会立即返回
    int result = f.get();
    std::cout << "The final result is: " << result << std::endl;

    worker.join();
    return 0;
}
```

**代码分析：**

在这个例子中，主线程进入一个 `while` 循环。每次循环，它调用 `f.wait_for(std::chrono::seconds(1))`，这会阻塞主线程**最多1秒钟**。

- 如果1秒内结果好了，`wait_for` 返回 `ready`，我们跳出循环。
- 如果1秒后结果还没好，`wait_for` 返回 `timeout`，主线程被唤醒，打印一条消息，然后继续下一次循环。

这样，主线程就不会被完全卡死，可以在等待结果的间隙中执行其他任务。

### 比较

| 函数             | 行为                                     | 用途                                                   |
| ---------------- | ---------------------------------------- | ------------------------------------------------------ |
| **`get()`**      | **阻塞**，直到结果就绪。                 | 当你必须拿到结果才能继续下一步时使用。                 |
| **`wait()`**     | **阻塞**，直到结果就绪（但不获取结果）。 | 只是为了同步，确保某个任务已完成。                     |
| **`wait_for()`** | **非阻塞**（或限时阻塞）。               | 在不想完全阻塞线程的情况下，周期性地检查结果是否就绪。 |

## 总结与高级用法

| 特性         | `std::promise`                             | `std::future`                              |
| ------------ | ------------------------------------------ | ------------------------------------------ |
| **角色**     | 生产者 / 写入端                            | 消费者 / 读取端                            |
| **主要目的** | 在未来的某个时刻**设置**一个值或异常。     | 在未来的某个时刻**获取**一个值或异常。     |
| **关键操作** | `set_value()`, `set_exception()`           | `get()`, `wait()`                          |
| **所有权**   | 对共享状态的唯一写入权，不可拷贝，可移动。 | 对共享状态的唯一读取权，不可拷贝，可移动。 |

**与 `std::async` 的关系:**

- **`std::promise`/`std::future`** 是最底层的构建模块，提供了最大的灵活性。
- **`std::async`** 是最高层的抽象。它能自动创建线程（或延迟执行）来运行一个函数，并直接返回一个 `std::future` 来获取该函数的结果。大多数情况下，如果你的需求只是简单地异步运行一个函数并获取其返回值，`std::async` 是更简单、更推荐的选择。

掌握 `std::promise` 和 `std::future` 是理解和构建复杂、灵活的多线程程序的关键。