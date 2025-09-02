# std::variant

`std::variant` 是 C++17 标准引入的一个类型安全的**联合体（Union）**，用于表示一个可以包含多种不同类型值中的一种的容器。你可以把它想象成一个“类型安全的联合体”或“可变类型”的容器。

### 主要用途和特点：

1.  **类型安全的联合体**：
    *   传统的 C 风格联合体（`union`）不记录当前存储的是哪种类型，程序员需要自己管理类型信息，容易出错。
    *   `std::variant` 内部会自动记录当前存储的是哪种类型，避免了类型混淆的问题。

2.  **存储多种类型之一**：
    *   你可以定义一个 `std::variant`，让它能够存储几种预定义的类型。例如：
        ```cpp
        #include <variant>
        #include <string>
        #include <iostream>
        
        int main() {
            // 定义一个可以存储 int、double 或 std::string 的 variant
            std::variant<int, double, std::string> v;
        
            v = 42;           // 现在 v 存储的是 int
            std::cout << std::get<int>(v) << std::endl; // 输出: 42
        
            v = 3.14;         // 现在 v 存储的是 double
            std::cout << std::get<double>(v) << std::endl; // 输出: 3.14
        
            v = "Hello";      // 现在 v 存储的是 std::string
            std::cout << std::get<std::string>(v) << std::endl; // 输出: Hello
        
            return 0;
        }
        ```

3.  **访问值**：
    *   **`std::get<T>(variant)`**：通过类型或索引获取值。如果当前存储的类型与请求的类型不匹配，会抛出 `std::bad_variant_access` 异常。
    *   **`std::get_if<T>(&variant)`**：返回一个指向存储值的指针。如果类型不匹配，返回 `nullptr`。这提供了一种更安全的访问方式。
    *   **`std::visit`**：最强大和推荐的方式，用于对 `variant` 中的值进行操作，无论它当前是哪种类型。它接受一个可调用对象（函数、lambda、函数对象）和一个或多个 `variant`，然后根据 `variant` 当前的类型调用相应的函数。
        ```cpp
        // 使用 std::visit 访问 variant
        struct Printer {
            void operator()(int i) const { std::cout << "int: " << i << std::endl; }
            void operator()(double d) const { std::cout << "double: " << d << std::endl; }
            void operator()(const std::string& s) const { std::cout << "string: " << s << std::endl; }
        };
        
        std::visit(Printer{}, v); // 根据 v 当前的类型调用相应的 operator()
        ```

4.  **状态检查**：
    *   **`std::holds_alternative<T>(variant)`**：检查 `variant` 是否当前存储的是类型 `T`。
    *   **`variant.index()`**：返回当前存储类型的索引（从 0 开始）。

5.  **异常安全**：
    *   如果 `variant` 的所有可能类型都满足一定的异常安全保证（如提供 `noexcept` 的移动构造函数），那么 `variant` 的操作也是异常安全的。

### 典型应用场景：

*   **解析配置文件或 JSON**：当某个字段的值可能是整数、浮点数、字符串、布尔值或数组时，`std::variant` 可以很好地表示这种“多态”数据。
*   **函数返回多种类型的结果**：例如，一个函数可能返回成功时的值，或者失败时的错误信息。
*   **状态机或事件处理**：不同的事件或状态可能携带不同类型的数据。
*   **替代 `void*` 或不安全的 `union`**：提供类型安全的替代方案。

### 总结

`std::variant` 是 C++ 中处理“一个值可能是多种类型之一”这种场景的现代、类型安全的解决方案。它比传统的 `union` 更安全，比继承层次结构更轻量，是现代 C++ 编程中处理异构数据的重要工具。