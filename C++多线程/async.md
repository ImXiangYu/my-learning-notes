# std::async

在上一篇文章中，我们已经了解了 `std::promise` 和 `std::future`，那么 `std::async` 就非常好懂了。`std::async` 是一个更高层次的抽象，它将**创建线程**、**传递参数**、**设置 promise** 以及**返回 future** 这些繁琐的步骤封装成了一个简单的函数调用。

## 核心思想：像调用普通函数一样启动异步任务

`std::async` 的主要目标是让你能够轻松地**异步地**运行一个函数，并方便地获取其未来的返回结果。

你可以把它看作是 `std::thread`, `std::promise`, `std::future` 的一个“便捷套餐”。你不需要手动管理 `promise`，也不需要手动创建 `thread` 对象。你只需告诉 `std::async`：“请帮我运行这个函数，然后给我一个能拿到结果的 `future` 就行了。”

## 基本用法

`std::async` 是一个定义在 `<future>` 头文件中的函数模板。它的基本形式如下：

```cpp
std::future<ReturnType> std::async(LaunchPolicy, Function, Args...);
```

- **`Function`**: 你想要异步执行的函数或任何可调用对象（例如 lambda 表达式）。
- **`Args...`**: 传递给这个函数的参数。
- **`LaunchPolicy`** (可选): 启动策略，这是一个非常关键的参数，我们稍后详细讲解。
- **返回值**: 它会立即返回一个 `std::future<ReturnType>` 对象，其中 `ReturnType` 是你传入函数的返回值类型。你可以通过这个 `future` 对象在之后获取函数的结果。

## 代码示例

让我们用 `std::async` 来重写之前那个耗时计算的例子：

```cpp
#include <iostream>
#include <future>
#include <chrono>

// 一个耗时的计算函数，现在它只是一个普通函数
int heavy_calculation(int input) {
    std::cout << "Worker task is starting the calculation..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(3));
    std::cout << "Worker task has finished." << std::endl;
    return 42 * input;
}

int main() {
    std::cout << "Main thread launching the calculation." << std::endl;
    
    // 1. 使用 std::async 启动异步任务
    // 它会自动处理线程创建和 promise/future 的连接
    // 我们明确指定 std::launch::async 策略，表示“必须在新线程中运行”
    std::future<int> result_future = std::async(std::launch::async, heavy_calculation, 2);

    // 2. 主线程可以做其他事情
    std::cout << "Main thread is doing other work while waiting..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // 3. 当需要结果时，调用 future::get()
    std::cout << "Main thread is now asking for the result." << std::endl;
    
    // get() 同样会阻塞，直到异步任务完成
    int result = result_future.get(); 

    std::cout << "The calculated result is: " << result << std::endl;

    return 0; // main 结束，result_future 销毁，后台线程（如果还在）会被处理
}
```

**对比一下：**

- **`std::promise` 版本**: 你需要手动创建 `promise`，获取 `future`，创建 `std::thread`，并把 `promise` `move` 进去，然后在工作函数里手动调用 `set_value()`。
- **`std::async` 版本**: 你只需一行代码 `std::async(...)`。它自动为你处理了所有底层细节。函数的 `return` 值会自动被用来满足 `promise` 的 `set_value()`。如果函数抛出异常，`std::async` 也会自动捕获并调用 `set_exception()`。

## 关键点：启动策略 (Launch Policy)

这是 `std::async` 最重要也最容易混淆的部分。通过启动策略，你可以告诉系统你希望如何运行这个异步任务。

1. **`std::launch::async`**
   - **含义**: **异步执行**。这会强制函数在一个**新的线程**中执行，类似于 `std::thread`。
   - **行为**: 函数会立即开始执行。
   - **用途**: 当你确定需要并发执行时，这是最常用的策略。
2. **`std::launch::deferred`**
   - **含义**: **延迟执行**。函数调用会被延迟，**不会**立刻启动新线程。
   - **行为**: 函数**直到**你对它返回的 `future` 调用 `.get()` 或 `.wait()` 时，才会在**调用 `.get()` 的那个线程**中同步执行。
   - **用途**: 用于实现懒加载（lazy evaluation）。如果你不确定将来是否真的需要这个计算结果，可以使用它。如果最终没有调用 `.get()`，那么这个耗时的函数就永远不会被执行，从而节省了资源。
3. **`std::launch::async | std::launch::deferred`** (默认值)
   - **含义**: **由系统决定**。这是默认策略，如果你不指定任何策略，就会使用这个。
   - **行为**: C++ 标准库的实现可以自由选择是立即在新线程中执行（像 `async`），还是延迟执行（像 `deferred`）。它可能会根据系统当前的线程负载来做出决定。
   - **警告**: 这个默认策略可能导致不确定的行为。如果你的代码依赖于任务必须并发执行，那么这种不确定性可能会引入难以调试的 bug。**因此，通常建议明确指定 `std::launch::async` 或 `std::launch::deferred`。**

## 一个重要的“陷阱”：`std::future` 的析构函数

`std::async` 返回的 `std::future` 有一个特殊的行为：

如果这个 `future` 是引用共享状态的最后一个对象，**它的析构函数将会阻塞，直到异步任务执行完毕**。

这个设计是为了防止主线程意外退出而导致异步任务还在访问已经被销毁的局部变量。

**看下面这个“即发即忘”(Fire and Forget) 的错误例子：**

```cpp
void some_task() {
    std::this_thread::sleep_for(std::chrono::seconds(2));
    std::cout << "Task finished." << std::endl;
}

void fire_and_forget() {
    std::cout << "Launching a task..." << std::endl;
    // 错误！async 返回的 future 是一个临时对象，会立刻被销毁
    std::async(std::launch::async, some_task); 
    std::cout << "Task launched (supposedly)." << std::endl;
} // fire_and_forget 函数结束，临时 future 对象在这里被销毁

// main 调用 fire_and_forget，主线程会在这里阻塞2秒！
// 因为临时 future 的析构函数会等待 some_task 完成。
// 这段代码的行为变成了同步执行，而不是异步。
```

**正确的做法是，即使你不在乎返回值，也要把 `future` 保存下来：**

```cpp
void fire_and_forget_correct() {
    std::cout << "Launching a task..." << std::endl;
    // 将 future 保存到一个变量中
    auto my_future = std::async(std::launch::async, some_task);
    std::cout << "Task launched." << std::endl;
    // 函数可以立即返回，异步任务在后台运行
    // my_future 的生命周期会延续到它所在作用域的结束
}
```

## `std::async` vs `std::thread`

| 特性         | `std::async`                             | `std::thread`                                                |
| ------------ | ---------------------------------------- | ------------------------------------------------------------ |
| **目的**     | **面向任务** (Task-based)                | **面向线程** (Thread-based)                                  |
| **返回值**   | 通过 `std::future` 自动处理              | 不直接处理，需要 `std::promise` 等手动设置                   |
| **异常处理** | 自动捕获函数异常，存储在 `future` 中     | 如果线程中出现未捕获的异常，程序会调用 `std::terminate` 崩溃 |
| **线程管理** | 由标准库管理，可能使用内部线程池，更高效 | 手动创建和销毁操作系统线程，开销较大                         |
| **所有权**   | 返回的 `future` 销毁时会同步等待任务结束 | 必须手动调用 `join()` 或 `detach()`，否则程序崩溃            |

## 总结

- **`std::async` 是启动异步任务并获取其结果的首选高级工具。**
- 它极大地简化了代码，将 `thread`+`promise`+`future` 的组合用法封装成了一个函数。
- **务必注意并明确指定启动策略** (`std::launch::async` 是最常用的)。
- **注意 `future` 的生命周期**，避免因临时 `future` 被销毁而导致的意外阻塞。
- 当你需要的是一个**“会返回结果的后台任务”**时，`std::async` 通常是比 `std::thread` 更好的选择。

## 关于 `std::future` 析构函数“陷阱”的补充

这个“陷阱”的关键在于：`std::async` 返回的 `std::future` 对象是一个“句柄”（handle），它代表着正在后台运行的任务。C++ 标准规定，为了程序安全（防止后台任务还在运行时，主程序就退出了），**这个句柄在被销毁（析构）时，必须等待它所代表的后台任务执行完毕**。

陷阱就发生在你**不小心让这个句柄过早地被销毁**的时候。

下边的程序中包含两种情况，以便加深理解：

1. **错误的方式**: 不保存 `std::async` 返回的 `future`，导致主线程意外阻塞。
2. **正确的方式**: 保存 `future`，让任务在后台真正地异步执行。

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <chrono>

// 一个需要运行3秒的后台任务
void long_task() {
    std::cout << "    [Task] ==> Starting the long task..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(3));
    std::cout << "    [Task] ==> Task finished." << std::endl;
}

// ------------------------------------------------------------------
// 错误示范：不保存 future，导致阻塞
// ------------------------------------------------------------------
void demo_blocking_destructor() {
    std::cout << "[Demo 1] Calling std::async without storing the future..." << std::endl;

    // 这行代码会发生以下事情：
    // 1. std::async 启动一个新线程来执行 long_task()。
    // 2. 它返回一个临时的 std::future 对象。
    // 3. 因为这个 future 没有被任何变量接收，它在这行语句结束时（在分号处）就会被销毁。
    // 4. 根据规则，future 的析构函数会等待 long_task() 执行完毕。
    // 5. 因此，你的程序会在这里“卡住”3秒钟。
    std::async(std::launch::async, long_task);

    std::cout << "[Demo 1] Function demo_blocking_destructor is about to return." << std::endl;
}


// ------------------------------------------------------------------
// 正确示范：保存 future，实现真正的异步
// ------------------------------------------------------------------
std::future<void> demo_non_blocking_destructor() {
    std::cout << "[Demo 2] Calling std::async AND storing the future..." << std::endl;
    
    // 这行代码会发生以下事情：
    // 1. std::async 启动一个新线程来执行 long_task()。
    // 2. 它返回一个 std::future 对象。
    // 3. 这个 future 被变量 "task_future" 保存了下来。
    // 4. 因此，在这行语句结束时，future 不会被销毁，程序可以立即继续执行。
    std::future<void> task_future = std::async(std::launch::async, long_task);

    std::cout << "[Demo 2] Function demo_non_blocking_destructor is returning immediately." << std::endl;
    
    // 我们将 future 返回给调用者，让它来决定何时等待任务结束。
    return task_future;
}


int main() {
    // ----- 案例1：观察阻塞现象 -----
    std::cout << "--- Running Demo 1: The Blocking Trap ---" << std::endl;
    auto start_time1 = std::chrono::high_resolution_clock::now();
    demo_blocking_destructor();
    auto end_time1 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration1 = end_time1 - start_time1;
    std::cout << "Demo 1 took " << duration1.count() << " seconds to complete.\n" << std::endl;

    std::cout << "-------------------------------------------\n" << std::endl;

    // ----- 案例2：观察异步现象 -----
    std::cout << "--- Running Demo 2: The Correct Asynchronous Way ---" << std::endl;
    auto start_time2 = std::chrono::high_resolution_clock::now();
    std::future<void> final_future = demo_non_blocking_destructor();
    auto end_time2 = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration2 = end_time2 - start_time2;
    std::cout << "Demo 2 function call returned in " << duration2.count() << " seconds." << std::endl;

    std::cout << "Main thread can do other work now..." << std::endl;
    // ... 在这里可以执行其他代码 ...

    std::cout << "Main thread now needs to wait for the task to be truly finished." << std::endl;
    // 我们在 main 函数的最后等待任务完成，这是正确的同步点。
    final_future.get(); 
    std::cout << "Task is confirmed to be finished. Exiting main." << std::endl;
    
    return 0;
}
```

这段代码在GCC13下会无法通过编译，因为 `std::async` 的返回值（`std::future`）被标记为 `[[nodiscard]]`，即不应被忽略。

可以在第25行，也就是没有返回值的async前加上 `static_cast<void>` 显式丢弃返回值。

> static_cast<void>(std::async(std::launch::async, long_task));

### 结果分析

```
--- Running Demo 1: The Blocking Trap ---
[Demo 1] Calling std::async without storing the future...
    [Task] ==> Starting the long task...
    [Task] ==> Task finished.
[Demo 1] Function demo_blocking_destructor is about to return.
Demo 1 took 3.00166 seconds to complete.

-------------------------------------------

--- Running Demo 2: The Correct Asynchronous Way ---
[Demo 2] Calling std::async AND storing the future...
    [Task] ==> Starting the long task...
[Demo 2] Function demo_non_blocking_destructor is returning immediately.
Demo 2 function call returned in 0.000885348 seconds.
Main thread can do other work now...
Main thread now needs to wait for the task to be truly finished.
    [Task] ==> Task finished.
Task is confirmed to be finished. Exiting main.
```

1. **Demo 1 (陷阱)**:
   - 程序在打印出 `"Calling std::async..."` 之后，**停顿了3秒**，然后才打印 `"Function demo_blocking_destructor is about to return."`。
   - 最终 `demo_blocking_destructor` 函数耗时约3秒。
   - **原因**: `std::async` 返回的 `future` 是个临时对象，在那一行的分号处就被销毁了。它的析构函数阻塞了 `demo_blocking_destructor` 函数的执行流程，直到后台任务 `long_task` 完成。这完全违背了异步的初衷。
2. **Demo 2 (正确方式)**:
   - 程序在打印出 `"Calling std::async..."` 之后，**立刻**就打印了 `"Function demo_non_blocking_destructor is returning immediately."`。
   - `demo_non_blocking_destructor` 函数本身耗时几乎为0秒，因为它立刻就返回了。
   - **原因**: `future` 被一个变量 `task_future` 接收，然后又被 `return` 给了 `main` 函数中的 `final_future`。只要 `final_future` 这个变量还存活，它所代表的后台任务就可以自由地在另一个线程中运行。
   - 真正的等待发生在 `main` 函数的最后，当我们调用 `final_future.get()` 时。这才是我们期望的、可控的同步行为。

### “陷阱”中得出的结论

**要想实现真正的异步执行，你必须将 `std::async` 返回的 `std::future` 保存到一个变量中。** 这个变量的生命周期决定了你允许后台任务运行多久。如果你只是想“发射后不管”，也要将 `future` 保存下来，否则它会变成“发射后，原地等待直到它完成”，失去了异步的意义。