# 有关的C/C++知识

## 头文件问题

由于头文件也可以 `#include` 其他头文件，为避免重复声明，通常会利用宏加入 include 防范（include guard）：

```C++
#ifndef LEPTJSON_H__
#define LEPTJSON_H__

/* ... */

#endif /* LEPTJSON_H__ */
```

宏的名字必须是唯一的，通常习惯以 *`H`*`_` 作为后缀。由于 leptjson 只有一个头文件，可以简单命名为 `LEPTJSON_H__`。如果项目有多个文件或目录结构，可以用 `项目名称_目录_文件名称_H__` 这种命名方式。

## 单元测试

一般我们会采用自动的测试方式，例如单元测试（unit testing）。单元测试也能确保其他人修改代码后，原来的功能维持正确（这称为回归测试／regression testing）。

常用的单元测试框架有 xUnit 系列，如 C++ 的 [Google Test](https://github.com/google/googletest)、C# 的 [NUnit](https://www.nunit.org/)。我们为了简单起见，会编写一个极简单的单元测试方式。

一般来说，软件开发是以周期进行的。例如，加入一个功能，再写关于该功能的单元测试。但也有另一种软件开发方法论，称为测试驱动开发（test-driven development, TDD），它的主要循环步骤是：

1. 加入一个测试。
2. 运行所有测试，新的测试应该会失败。
3. 编写实现代码。
4. 运行所有测试，若有测试失败回到3。
5. 重构代码。
6. 回到 1。

TDD 是先写测试，再实现功能。好处是实现只会刚好满足测试，而不会写了一些不需要的代码，或是没有被测试的代码。

但无论我们是采用 TDD，或是先实现后测试，都应尽量加入足够覆盖率的单元测试。

## const char *p

const char *p 的含义是：

p 是一个指向"常量字符"的指针。你不能通过 p 修改它指向的内容，但你可以修改 p 本身的值（即让它指向别的地方）。即指针指向的值不可变，但指针可变。

## 断言

**release版本assert不生效，debug版本生效**

断言（assertion）是 C 语言中常用的防御式编程方式，减少编程错误。最常用的是在函数开始的地方，检测所有参数。有时候也可以在调用函数后，检查上下文是否正确。

C 语言的标准库含有 `assert()` 这个宏（需 `#include <assert.h>`），提供断言功能。当程序以 release 配置编译时（定义了 `NDEBUG` 宏），`assert()` 不会做检测；而当在 debug 配置时（没定义 `NDEBUG` 宏），则会在运行时检测 `assert(cond)` 中的条件是否为真（非 0），断言失败会直接令程序崩溃。

初使用断言的同学，可能会错误地把含[副作用](https://en.wikipedia.org/wiki/Side_effect_(computer_science))的代码放在 `assert()` 中：

```C
assert(x++ == 0); /* 这是错误的! */
```

这样会导致 debug 和 release 版的行为不一样。

### 断言or异常？

初学者可能会难于分辨何时使用断言，何时处理运行时错误（如返回错误值或在 C++ 中抛出异常）。简单的答案是，如果那个错误是由于程序员错误编码所造成的（例如传入不合法的参数），那么应用断言；如果那个错误是程序员无法避免，而是由运行时的环境所造成的，就要处理运行时错误（例如开启文件失败）。

## \0

在 C 语言中，\0 是 字符串的结束符（null character），用于表示一个字符串的终止。

## 学习使用valgrind

学习使用valgrind，对内存进行分析，查看是否有内存泄漏

一开始想在windows下使用valgrind，但发现不支持，就是用了wsl

在CLion中修改成了WSL工具链，对程序进行编译，可以正常使用valgrind

![img](https://acnbif3emsdd.feishu.cn/space/api/box/stream/download/asynccode/?code=YTA3MzAwY2EyODYzNGJmNGU2NzJlMWFhNWU1NjlmOGZfSk02TEp6ekVWT0xsSEhyVzQyZWxLaDQ5QktUcmwybW5fVG9rZW46R0VRSmJBcTE3b21vcE94RzU4ZWNiaGljbkVnXzE3NTU3MDk2OTA6MTc1NTcxMzI5MF9WNA)

valgrind --tool=memcheck --leak-check=full ./tutorial03/cmake-build-debug/leptjson_test

使用如上指令可以对内存进行分析

![img](https://acnbif3emsdd.feishu.cn/space/api/box/stream/download/asynccode/?code=NzAwZDMzYzI2MDZjZThiYWRjNzE5YjRmMWM5NWQ4ODVfQnZhbHNpbFFDSEwwc25haXNOZVN2UTJMNjlTand2Z1dfVG9rZW46S2NvYWJxSlJYb3QyeGl4MURpSGMxU2RvblhkXzE3NTU3MDk2OTA6MTc1NTcxMzI5MF9WNA)

如果故意造成泄露的话，使用valgrind可以查出来

### 后续使用

继续使用valgrind查内存泄漏，发现忘记带参数

![img](https://acnbif3emsdd.feishu.cn/space/api/box/stream/download/asynccode/?code=OTUyMjVmZmI2MWYyZmM4MDQzMWU2N2VlMTllOTVjMWVfSjJ2TGNYelI3MXp6Vk5zZVo2bGhGTGMwZnhDY0U2b2VfVG9rZW46V3VwcWJHWmUyb0JkT0Z4cmZ4SWN0ZTN5bmloXzE3NTU3MDk3MTQ6MTc1NTcxMzMxNF9WNA)

提醒我带上--leak-check=full可以查看更多细节

![img](https://acnbif3emsdd.feishu.cn/space/api/box/stream/download/asynccode/?code=ZDY3NDhlMWIxNGY3MmNjMDZmMjhhYTczOGNkYzg5YzJfbzlsUWtzOTFEc1RETWYxQzFDd2hxYmQ0MlhZbWtrOWJfVG9rZW46RDlRMGJZa0Y1b1BlUm54TWhPa2N0dURQbnNkXzE3NTU3MDk3MTQ6MTc1NTcxMzMxNF9WNA)

带参数后会有更细致的检查