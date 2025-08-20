# JSON的数据结构及实现细节

## JSON的数据类型

JSON 是树状结构，而 JSON 只包含 6 种数据类型：

- null: 表示为 null
- boolean: 表示为 true 或 false
- number: 一般的浮点数表示方式，在下一单元详细说明
- string: 表示为 "..."
- array: 表示为 [ ... ]
- object: 表示为 { ... }

## JSON语法子集

```JavaScript
JSON-text = ws value ws
ws = *(%x20 / %x09 / %x0A / %x0D)
value = null / false / true 
null  = "null"
false = "false"
true  = "true"
```

当中 `%xhh` 表示以 16 进制表示的字符，`/` 是多选一，`*` 是零或多个，`()` 用于分组。

那么第一行的意思是，JSON 文本由 3 部分组成，首先是空白（whitespace），接着是一个值，最后是空白。

第二行告诉我们，所谓空白，是由零或多个空格符（space U+0020）、制表符（tab U+0009）、换行符（LF U+000A）、回车符（CR U+000D）所组成。

第三行是说，我们现时的值只可以是 null、false 或 true，它们分别有对应的字面值（literal）。

我们的解析器应能判断输入是否一个合法的 JSON。如果输入的 JSON 不合符这个语法，我们要产生对应的错误码，方便使用者追查问题。

因此，在这个JSON语法子集下，我们定义如下三种错误码：

- 若一个 JSON 只含有空白，传回 `LEPT_PARSE_EXPECT_VALUE`。
- 若一个值之后，在空白之后还有其他字符，传回 `LEPT_PARSE_ROOT_NOT_SINGULAR`。
- 若值不是那三种字面值，传回 `LEPT_PARSE_INVALID_VALUE`。

## 递归下降解析器

leptjson 是一个手写的递归下降解析器（recursive descent parser）。由于 JSON 语法特别简单，我们不需要写分词器（tokenizer），只需检测下一个字符，便可以知道它是哪种类型的值，然后调用相关的分析函数。对于完整的 JSON 语法，跳过空白后，只需检测当前字符：

- n ➔ null
- t ➔ true
- f ➔ false
- " ➔ string
- 0-9/- ➔ number
- [ ➔ array
- { ➔ object

## JSON数字语法

JSON number

```Java
number = [ "-" ] int [ frac ] [ exp ]
int = "0" / digit1-9 *digit
frac = "." 1*digit
exp = ("e" / "E") ["-" / "+"] 1*digit
```

number 是以十进制表示，它主要由 4 部分顺序组成：负号、整数、小数、指数。只有整数是必需部分。注意和直觉可能不同的是，正号是不合法的。

整数部分如果是 0 开始，只能是单个 0；而由 1-9 开始的话，可以加任意数量的数字（0-9）。也就是说，`0123` 不是一个合法的 JSON 数字。

小数部分比较直观，就是小数点后是一或多个数字（0-9）。

JSON 可使用科学记数法，指数部分由大写 E 或小写 e 开始，然后可有正负号，之后是一或多个数字（0-9）。

## JSON数组

JSON 数组的语法：

```Plain
array = %x5B ws [ value *( ws %x2C ws value ) ] ws %x5D
```

当中，`%x5B` 是左中括号 `[`，`%x2C` 是逗号 `,`，`%x5D` 是右中括号 `]` ，`ws` 是空白字符。一个数组可以包含零至多个值，以逗号分隔，例如 `[]`、`[1,2,true]`、`[[1,2],[3,4],"abc"]` 都是合法的数组。但注意 JSON 不接受末端额外的逗号，例如 `[1,2,]` 是不合法的

## JSON数组的解析

我们在解析 JSON 字符串时，因为在开始时不能知道字符串的长度，而又需要进行转义，所以需要一个临时缓冲区去存储解析后的结果。我们为此实现了一个动态增长的堆栈，可以不断压入字符，最后一次性把整个字符串弹出，复制至新分配的内存之中。

对于 JSON 数组，我们也可以用相同的方法，而且，我们可以用同一个堆栈！我们只需要把每个解析好的元素压入堆栈，解析到数组结束时，再一次性把所有元素弹出，复制至新分配的内存之中。

但和字符串有点不一样，如果把 JSON 当作一棵树的数据结构，JSON 字符串是叶节点，而 JSON 数组是中间节点。在叶节点的解析函数中，我们怎样使用那个堆栈也可以，只要最后还原就好了。但对于数组这样的中间节点，共用这个堆栈没问题么？

答案是：只要在解析函数结束时还原堆栈的状态，就没有问题。

## JSON对象

JSON 对象和 JSON 数组非常相似，区别包括 JSON 对象以花括号 `{}`（`U+007B`、`U+007D`）包裹表示，另外 JSON 对象由对象成员（member）组成，而 JSON 数组由 JSON 值组成。所谓对象成员，就是键值对，键必须为 JSON 字符串，然后值是任何 JSON 值，中间以冒号 `:`（`U+003A`）分隔。完整语法如下：

```Plain
member = string ws %x3A ws value
object = %x7B ws [ member *( ws %x2C ws member ) ] ws %x7D
```

一个JSON对象，key是字符串，value可以是任何JSON类型

```JSON
{
    "n" : null ,
    "f": false ,
    "t" : true ,
    "i" : 123 ,
    "s" : "abc",
    "a" : [ 1, 2, 3 ],
    "o" : { "1" : 1, "2" : 2, "3" : 3 }
} 
```