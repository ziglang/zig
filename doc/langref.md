# Language Reference

## Grammar

```
Root = many(TopLevelDecl) "EOF"

TopLevelDecl = many(Directive) option(VisibleMod) (FnDef | ExternDecl | ContainerDecl | GlobalVarDecl | ErrorValueDecl | TypeDecl | UseDecl)

TypeDecl = "type" Symbol "=" TypeExpr ";"

ErrorValueDecl = "error" Symbol ";"

GlobalVarDecl = VariableDeclaration ";"

VariableDeclaration = ("var" | "const") Symbol option(":" TypeExpr) "=" Expression

ContainerDecl = ("struct" | "enum" | "union") Symbol option(ParamDeclList) "{" many(StructMember) "}"

StructMember = many(Directive) option(VisibleMod) (StructField | FnDef | GlobalVarDecl | ContainerDecl)

StructField = Symbol option(":" Expression) ",")

UseDecl = "use" Expression ";"

ExternDecl = "extern" (FnProto | VariableDeclaration) ";"

FnProto = "fn" option(Symbol) ParamDeclList option("->" TypeExpr)

Directive = "#" Symbol "(" Expression ")"

VisibleMod = "pub" | "export"

FnDef = option("inline" | "extern") FnProto Block

ParamDeclList = "(" list(ParamDecl, ",") ")"

ParamDecl = option("noalias" | "inline") option(Symbol ":") TypeExpr | "..."

Block = "{" list(option(Statement), ";") "}"

Statement = Label | VariableDeclaration ";" | Defer ";" | NonBlockExpression ";" | BlockExpression

Label = Symbol ":"

Expression = BlockExpression | NonBlockExpression

TypeExpr = PrefixOpExpression

NonBlockExpression = ReturnExpression | AssignmentExpression

AsmExpression = "asm" option("volatile") "(" String option(AsmOutput) ")"

AsmOutput = ":" list(AsmOutputItem, ",") option(AsmInput)

AsmInput = ":" list(AsmInputItem, ",") option(AsmClobbers)

AsmOutputItem = "[" Symbol "]" String "(" (Symbol | "->" TypeExpr) ")"

AsmInputItem = "[" Symbol "]" String "(" Expression ")"

AsmClobbers= ":" list(String, ",")

UnwrapExpression = BoolOrExpression (UnwrapMaybe | UnwrapError) | BoolOrExpression

UnwrapMaybe = "??" Expression

UnwrapError = "%%" option("|" Symbol "|") Expression

AssignmentExpression = UnwrapExpression AssignmentOperator UnwrapExpression | UnwrapExpression

AssignmentOperator = "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "^=" | "|=" | "&&=" | "||=" | "*%=" | "+%=" | "-%=" | "<<%="

BlockExpression = IfExpression | Block | WhileExpression | ForExpression | SwitchExpression

SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"

SwitchProng = (list(SwitchItem, ",") | "else") "=>" option("|" Symbol "|") Expression ","

SwitchItem = Expression | (Expression "..." Expression)

WhileExpression = "while" "(" Expression option(";" Expression) ")" Expression

ForExpression = "for" "(" Expression ")" option("|" option("*") Symbol option("," Symbol) "|") Expression

BoolOrExpression = BoolAndExpression "||" BoolOrExpression | BoolAndExpression

ReturnExpression = option("%" | "?") "return" option(Expression)

Defer = option("%" | "?") "defer" option(Expression)

IfExpression = IfVarExpression | IfBoolExpression

IfBoolExpression = "if" "(" Expression ")" Expression option(Else)

IfVarExpression = "if" "(" ("const" | "var") option("*") Symbol option(":" TypeExpr) "?=" Expression ")" Expression Option(Else)

Else = "else" Expression

BoolAndExpression = ComparisonExpression "&&" BoolAndExpression | ComparisonExpression

ComparisonExpression = BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression

ComparisonOperator = "==" | "!=" | "<" | ">" | "<=" | ">="

BinaryOrExpression = BinaryXorExpression "|" BinaryOrExpression | BinaryXorExpression

BinaryXorExpression = BinaryAndExpression "^" BinaryXorExpression | BinaryAndExpression

BinaryAndExpression = BitShiftExpression "&" BinaryAndExpression | BitShiftExpression

BitShiftExpression = AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression

BitShiftOperator = "<<" | ">>" | "<<%"

AdditionExpression = MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression

AdditionOperator = "+" | "-" | "++" | "+%" | "-%"

MultiplyExpression = CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression

CurlySuffixExpression = TypeExpr option(ContainerInitExpression)

MultiplyOperator = "*" | "/" | "%" | "**" | "*%"

PrefixOpExpression = PrefixOp PrefixOpExpression | SuffixOpExpression

SuffixOpExpression = PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)

FieldAccessExpression = "." Symbol

FnCallExpression = "(" list(Expression, ",") ")"

ArrayAccessExpression = "[" Expression "]"

SliceExpression = "[" Expression "..." option(Expression) "]" option("const")

ContainerInitExpression = "{" ContainerInitBody "}"

ContainerInitBody = list(StructLiteralField, ",") | list(Expression, ",")

StructLiteralField = "." Symbol "=" Expression

PrefixOp = "!" | "-" | "~" | "*" | ("&" option("const")) | "?" | "%" | "%%" | "??" | "-%"

PrimaryExpression = Number | String | CharLiteral | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression | Symbol | ("@" Symbol FnCallExpression) | ArrayType | (option("extern") FnProto) | AsmExpression | ("error" "." Symbol)

ArrayType = "[" option(Expression) "]" option("const") TypeExpr

GotoExpression = "goto" Symbol

GroupedExpression = "(" Expression ")"

KeywordLiteral = "true" | "false" | "null" | "break" | "continue" | "undefined" | "error" | "type"
```

## Operator Precedence

```
x() x[] x.y
!x -x ~x *x &x ?x %x %%x
x{}
* / %
+ - ++
<< >>
&
^
|
== != < > <= >=
&&
||
?? %%
= *= /= %= += -= <<= >>= &= ^= |= &&= ||=
```

## Types

### Numeric Types

```
Type name       C equivalent        Description

i8              int8_t              signed 8-bit integer
u8              uint8_t             unsigned 8-bit integer
i16             int16_t             signed 16-bit integer
u16             uint16_t            unsigned 16-bit integer
i32             int32_t             signed 32-bit integer
u32             uint32_t            unsigned 32-bit integer
i64             int64_t             signed 64-bit integer
u64             uint64_t            unsigned 64-bit integer
isize           intptr_t            signed pointer sized integer
usize           uintptr_t           unsigned pointer sized integer

c_short         short               for ABI compatibility with C
c_ushort        unsigned short      for ABI compatibility with C
c_int           int                 for ABI compatibility with C
c_uint          unsigned int        for ABI compatibility with C
c_long          long                for ABI compatibility with C
c_ulong         unsigned long       for ABI compatibility with C
c_longlong      long long           for ABI compatibility with C
c_ulonglong     unsigned long long  for ABI compatibility with C
c_long_double   long double         for ABI compatibility with C
c_void          void                for ABI compatibility with C

f32             float               32-bit floating point
f64             double              64-bit floating point
```

### Boolean Type

The boolean type has the name `bool` and represents either true or false.

### Function Type

TODO

### Fixed-Size Array Type

Example: The string `"aoeu"` has type `[4]u8`.

The size is known at compile time and is part of the type.

### Slice Type

A slice can be obtained with the slicing syntax: `array[start...end]`

Example: `"aoeu"[0...2]` has type `[]u8`.

### Struct Type

TODO

### Enum Type

TODO

### Maybe Type

TODO

### Pure Error Type

TODO

### Error Union Type

TODO

### Pointer Type

TODO

### Unreachable Type

The unreachable type has the name `unreachable`. TODO explanation

### Void Type

The void type has the name `void`. void types are zero bits and are omitted
from codegen.


## Expressions

### Literals

#### Character and String Literals

```
Literal            Example       Characters   Escapes         Null Term  Type

Byte               'H'           All ASCII    Byte            No         u8
UTF-8 Bytes        "hello"       All Unicode  Byte & Unicode  No         [5]u8
UTF-8 C string     c"hello"      All Unicode  Byte & Unicode  Yes        &const u8
```

### Escapes

 Escape   | Name
----------|-------------------------------------------------------------------
 \n       | Newline
 \r       | Carriage Return
 \t       | Tab
 \\       | Backslash
 \'       | Single Quote
 \"       | Double Quote
 \xNN     | hexadecimal 8-bit character code (2 digits)
 \uNNNN   | hexadecimal 16-bit Unicode character code UTF-8 encoded (4 digits)
 \UNNNNNN | hexadecimal 24-bit Unicode character code UTF-8 encoded (6 digits)

Note that the maximum valid Unicode point is 0x10ffff.

##### Multiline String Literals

Multiline string literals have no escapes and can span across multiple lines.
To start a multiline string literal, use the `\\` token. Just like a comment,
the string literal goes until the end of the line. The end of the line is not
included in the string literal.

However, if the next line begins with `\\` then a newline is appended and
the string literal continues.

Example:

```zig
const hello_world_in_c =
    \\#include <stdio.h>
    \\
    \\int main(int argc, char **argv) {
    \\    printf("hello world\n");
    \\    return 0;
    \\}
;
```

For a multiline C string literal, prepend `c` to each `\\`. Example:

```zig
const c_string_literal =
    c\\#include <stdio.h>
    c\\
    c\\int main(int argc, char **argv) {
    c\\    printf("hello world\n");
    c\\    return 0;
    c\\}
;
```

In this example the variable `c_string_literal` has type `&const char` and
has a terminating null byte.

#### Number Literals

 Number literals    | Example     | Exponentiation
--------------------|-------------|--------------
 Decimal integer    | 98222       | N/A
 Hex integer        | 0xff        | N/A
 Octal integer      | 0o77        | N/A
 Binary integer     | 0b11110000  | N/A
 Floating point     | 123.0E+77   | Optional
 Hex floating point | 0x103.70p-5 | Optional

### Identifiers

TODO

### Declarations

Declarations have type `void`.

#### Function Declarations

TODO

#### Variable Declarations

TODO

#### Struct Declarations

TODO

#### Enum Declarations

TODO


## Built-in Functions

Built-in functions are prefixed with `@`. Remember that the `inline` keyword on
a parameter means that the parameter must be known at compile time.

### @typeof(expression) -> type

This function returns a compile-time constant, which is the type of the
expression passed as an argument. The expression is *not evaluated*.

### @sizeof(inline T: type) -> (number literal)

This function returns the number of bytes it takes to store T in memory.

The result is a target-specific compile time constant.

### @alignof(inline T: type) -> (number literal)

This function returns the number of bytes that this type should be aligned to
for the current target.

The result is a target-specific compile time constant.

### Overflow Arithmetic

These functions take an integer type, two variables of the specified type,
and a pointer to memory of the specified type where the result is stored.

The functions return a boolean value: true if overflow or underflow occurred,
false otherwise.

```
Function                                                             Operation
@add_with_overflow(inline T: type, a: T, b: T, result: &T) -> bool   *x = a + b
@sub_with_overflow(inline T: type, a: T, b: T, result: &T) -> bool   *x = a - b
@mul_with_overflow(inline T: type, a: T, b: T, result: &T) -> bool   *x = a * b
@shl_with_overflow(inline T: type, a: T, b: T, result: &T) -> bool   *x = a << b
```

### @memset(dest, c: u8, byte_count: usize)

This function sets a region of memory to `c`. `dest` is a pointer.

This function is a low level intrinsic with no safety mechanisms. Most higher
level code will not use this function, instead using something like this:

```zig
// assume dest is a slice
for (dest) |*b| *b = c;
```

### @memcpy(dest, source, byte_count: usize)

This function copies bytes from one region of memory to another. `dest` and
`source` are both pointers and must not overlap.

This function is a low level intrinsic with no safety mechanisms. Most higher
level code will not use this function, instead using something like this:

```zig
const mem = @import("std").mem;
// assume dest and source are slices
mem.copy(dest, source);
```

### @breakpoint()

This function inserts a platform-specific debug trap instruction which causes
debuggers to break there.

This function is only valid within function scope.

### @return_address()

This function returns a pointer to the return address of the current stack
frame.

The implications of this are target specific and not consistent across
all platforms.

This function is only valid within function scope.

### @frame_address()

This function returns the base pointer of the current stack frame.

The implications of this are target specific and not consistent across all
platforms. The frame address may not be available in release mode due to
aggressive optimizations.

This function is only valid within function scope.

### @max_value(inline T: type) -> (number literal)

This function returns the maximum integer value of the integer type T.

The result is a compile time constant. For some types such as `c_long`, the
result is marked as depending on a compile variable.

### @min_value(inline T: type) -> (number literal)

This function returns the minimum integer value of the integer type T.

The result is a compile time constant. For some types such as `c_long`, the
result is marked as depending on a compile variable.

### @member_count(inline T: type) -> (number literal)

This function returns the number of enum values in an enum type.

The result is a compile time constant.

### @import(inline path: []u8) -> (namespace)

This function finds a zig file corresponding to `path` and imports all the
public top level declarations into the resulting namespace.

`path` can be a relative or absolute path, or it can be the name of a package,
such as "std".

This function is only valid at top level scope.

### @c_import(expression) -> (namespace)

This function parses C code and imports the functions, types, variables, and
compatible macro definitions into the result namespace.

`expression` is interpreted at compile time. The builtin functions
`@c_include`, `@c_define`, and `@c_undef` work within this expression,
appending to a temporary buffer which is then parsed as C code.

This function is only valid at top level scope.

### @c_include(inline path: []u8)

This function can only occur inside `@c_import`.

This appends `#include <$path>\n` to the `c_import` temporary buffer.

### @c_define(inline name: []u8, value)

This function can only occur inside `@c_import`.

This appends `#define $name $value` to the `c_import` temporary buffer.

### @c_undef(inline name: []u8)

This function can only occur inside `@c_import`.

This appends `#undef $name` to the `c_import` temporary buffer.

### @compile_var(inline name: []u8) -> (varying type)

This function returns a compile-time variable. There are built in compile
variables:

 * "is_big_endian" `bool` - either `true` for big endian or `false` for little endian.
 * "is_release" `bool`- either `true` for release mode builds or `false` for debug mode builds.
 * "is_test" `bool`- either `true` for test builds or `false` otherwise.
 * "os" `@OS` - use `zig targets` to see what enum values are possible here.
 * "arch" `@Arch` - use `zig targets` to see what enum values are possible here.
 * "environ" `@Environ` - use `zig targets` to see what enum values are possible here.

Build scripts can set additional compile variables of any name and type.

The result of this function is a compile time constant that is marked as
depending on a compile variable.

### @const_eval(expression) -> @typeof(expression)

This function wraps an expression and generates a compile error if the
expression is not known at compile time.

The result of the function is the result of the expression.

### @ctz(inline T: type, x: T) -> T

This function counts the number of trailing zeroes in x which is an integer
type T.

### @clz(inline T: type, x: T) -> T

This function counts the number of leading zeroes in x which is an integer
type T.

### @err_name(err: error) -> []u8

This function returns the string representation of an error. If an error
declaration is:

```zig
error OutOfMem;
```

Then the string representation is "OutOfMem".

If there are no calls to `@err_name` in an entire application, then no error
name table will be generated.

### @embed_file(inline path: []u8) -> [X]u8

This function returns a compile time constant fixed-size array with length
equal to the byte count of the file given by `path`. The contents of the array
are the contents of the file.

### @cmpxchg(ptr: &T, cmp: T, new: T, success_order: MemoryOrder, fail_order: MemoryOrder) -> bool

This function performs an atomic compare exchange operation.

### @fence(order: MemoryOrder)

The `fence` function is used to introduce happens-before edges between operations.

### @div_exact(a: T, b: T) -> T

This function performs integer division `a / b` and returns the result.

The caller guarantees that this operation will have no remainder.

In debug mode, a remainder causes a panic. In release mode, a remainder is
undefined behavior.

### @truncate(inline T: type, integer) -> T

This function truncates bits from an integer type, resulting in a smaller
integer type.

The following produces a crash in debug mode and undefined behavior in
release mode:

```zig
const a: u16 = 0xabcd;
const b: u8 = u8(a);
```

However this is well defined and working code:

```zig
const a: u16 = 0xabcd;
const b: u8 = @truncate(u8, a);
// b is now 0xcd
```

### @compile_err(inline msg: []u8)

This function, when semantically analyzed, causes a compile error with the message `msg`.

There are several ways that code avoids being semantically checked, such as using `if`
or `switch` with compile time constants, and inline functions.

### @int_type(inline is_signed: bool, inline bit_count: u8) -> type

This function returns an integer type with the given signness and bit count.
