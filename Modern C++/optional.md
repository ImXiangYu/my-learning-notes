# std::optional

`std::optional` 是 C++17 标准引入的一个模板类，用于表示**一个值可能存在，也可能不存在**。

你可以把它想象成一个“可选的容器”，里面要么包含一个类型为 `T` 的值，要么是空的（表示没有值）。

### 核心用途

`std::optional` 主要用来解决以下问题：

1.  **明确表示“无值”状态**：在很多情况下，函数可能无法返回一个有效的值（例如查找失败、计算错误等）。过去常用的方法有：
    *   使用特殊值（如指针返回 `nullptr`，数值返回 `-1` 或特殊标记）。
    *   通过引用参数返回值，并用返回值表示成功/失败。
    *   抛出异常。
    这些方法要么不安全（特殊值可能被误用），要么不够清晰（调用者容易忽略错误返回值），要么开销大（异常）。

    `std::optional` 提供了一种**类型安全且语义清晰**的方式来表示“可能没有值”的情况。

2.  **避免使用指针或全局错误状态**：它提供了一种比裸指针更安全、比全局错误码（如 `errno`）更局部化的方式来处理可选值。

3.  **函数返回值**：这是最常见的用法。当一个函数可能无法产生有效结果时，可以返回 `std::optional<T>`。

### 基本用法

```cpp
#include <iostream>
#include <optional> // C++17
#include <string>

// 示例：一个可能找不到元素的查找函数
std::optional<int> findValue(const std::vector<int>& vec, int target) {
    for (size_t i = 0; i < vec.size(); ++i) {
        if (vec[i] == target) {
            return i; // 找到，返回索引
        }
    }
    return std::nullopt; // 没找到，返回空 optional
}

int main() {
    std::vector<int> numbers = {10, 20, 30, 40, 50};

    // 使用 std::optional 接收返回值
    std::optional<int> result = findValue(numbers, 30);

    // 检查是否有值
    if (result.has_value()) {
        std::cout << "Found at index: " << result.value() << std::endl;
        // 或者直接解引用: std::cout << "Found at index: " << *result << std::endl;
    } else {
        std::cout << "Value not found." << std::endl;
    }

    // 也可以用更简洁的方式检查（optional 对象在 bool 上下文中可转换）
    if (result) {
        std::cout << "Found at index: " << *result << std::endl;
    }

    // 访问值（如果不存在会抛出异常 std::bad_optional_access）
    try {
        int index = result.value();
    } catch (const std::bad_optional_access& e) {
        std::cout << "Error: " << e.what() << std::endl;
    }

    // 获取值，如果不存在则返回默认值
    int safeIndex = result.value_or(-1); // 如果 result 为空，则返回 -1

    return 0;
}
```

### 关键成员函数和操作

*   **构造与赋值**:
    *   `std::optional<T> opt;` // 默认构造，为空
    *   `std::optional<T> opt(value);` // 用值构造，包含 `value`
    *   `opt = std::nullopt;` // 赋值为空
    *   `opt = value;` // 赋值为 `value`
*   **状态检查**:
    *   `opt.has_value()` 或 `bool(opt)` // 检查是否包含值
*   **访问值**:
    *   `opt.value()` // 获取值，如果为空则抛出 `std::bad_optional_access`
    *   `*opt` // 解引用操作符，获取值，如果为空则行为未定义（通常崩溃）
    *   `opt.value_or(default_value)` // 获取值，如果为空则返回提供的默认值
*   **其他**:
    *   `opt.emplace(args...)` // 原地构造 `T` 的值
    *   `opt.reset()` // 清除值，使其变为空

### 优点

*   **类型安全**：编译器可以检查你是否处理了“无值”情况（虽然不是强制的，但模式更清晰）。
*   **语义清晰**：代码明确表达了“这个值可能不存在”的意图。
*   **避免错误**：减少了因忽略错误返回值或误用特殊值而导致的 bug。
*   **值语义**：`std::optional` 本身具有值语义，可以像普通对象一样拷贝、移动。

### 总结

`std::optional` 是 C++ 中处理“可能存在或不存在的值”的现代、安全且清晰的方式。它特别适用于函数返回值，当函数执行可能失败或没有合理结果时，使用 `std::optional<T>` 比使用指针、引用参数或异常（对于非异常情况）通常是更好的选择。