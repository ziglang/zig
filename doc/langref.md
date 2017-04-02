# Language Reference

## Grammar

```
Root = many(TopLevelItem) "EOF"

TopLevelItem = ErrorValueDecl | CompTimeExpression(Block) | TopLevelDecl | TestDecl

TestDecl = "test" String Block

TopLevelDecl = option(VisibleMod) (FnDef | ExternDecl | GlobalVarDecl | TypeDecl | UseDecl)

TypeDecl = "type" Symbol "=" TypeExpr ";"

ErrorValueDecl = "error" Symbol ";"

GlobalVarDecl = VariableDeclaration ";"

VariableDeclaration = option("comptime") ("var" | "const") Symbol option(":" TypeExpr) "=" Expression

ContainerMember = (ContainerField | FnDef | GlobalVarDecl)

ContainerField = Symbol option(":" Expression) ","

UseDecl = "use" Expression ";"

ExternDecl = "extern" (FnProto | VariableDeclaration) ";"

FnProto = option("coldcc" | "nakedcc") "fn" option(Symbol) ParamDeclList option("->" TypeExpr)

VisibleMod = "pub" | "export"

FnDef = option("inline" | "extern") FnProto Block

ParamDeclList = "(" list(ParamDecl, ",") ")"

ParamDecl = option("noalias" | "comptime") option(Symbol ":") (TypeExpr | "...")

Block = "{" many(Statement) option(Expression) "}"

Statement = Label | VariableDeclaration ";" | Defer(Block) | Defer(Expression) ";" | BlockExpression(Block) | Expression ";" | ";"

Label = Symbol ":"

TypeExpr = PrefixOpExpression | "var"

BlockOrExpression = Block | Expression

Expression = ReturnExpression | AssignmentExpression

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

AssignmentOperator = "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "^=" | "|=" | "*%=" | "+%=" | "-%=" | "<<%="

BlockExpression(body) = Block | IfExpression(body) | TryExpression(body) | WhileExpression(body) | ForExpression(body) | SwitchExpression | CompTimeExpression(body)

CompTimeExpression(body) = "comptime" body

SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"

SwitchProng = (list(SwitchItem, ",") | "else") "=>" option("|" option("*") Symbol "|") Expression ","

SwitchItem = Expression | (Expression "..." Expression)

WhileExpression(body) = option("inline") "while" "(" Expression option(";" Expression) ")" body

ForExpression(body) = option("inline") "for" "(" Expression ")" option("|" option("*") Symbol option("," Symbol) "|") body

BoolOrExpression = BoolAndExpression "or" BoolOrExpression | BoolAndExpression

ReturnExpression = option("%" | "?") "return" option(Expression)

Defer(body) = option("%" | "?") "defer" body

IfExpression(body) = IfVarExpression(body) | IfBoolExpression(body)

IfBoolExpression(body) = "if" "(" Expression ")" body option("else" BlockExpression(body))

TryExpression(body) = "try" "(" option(("const" | "var") option("*") Symbol "=") Expression  ")" body option("else" option("|" Symbol "|") BlockExpression(body))

IfVarExpression(body) = "if" "(" ("const" | "var") option("*") Symbol option(":" TypeExpr) "?=" Expression ")" body Option("else" BlockExpression(body))

BoolAndExpression = ComparisonExpression "and" BoolAndExpression | ComparisonExpression

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

PrefixOp = "!" | "-" | "~" | "*" | ("&" option("const") option("volatile")) | "?" | "%" | "%%" | "??" | "-%"

PrimaryExpression = Number | String | CharLiteral | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression(BlockOrExpression) | Symbol | ("@" Symbol FnCallExpression) | ArrayType | (option("extern") FnProto) | AsmExpression | ("error" "." Symbol) | ContainerDecl

ArrayType = "[" option(Expression) "]" option("const") TypeExpr

GotoExpression = "goto" Symbol

GroupedExpression = "(" Expression ")"

KeywordLiteral = "true" | "false" | "null" | "break" | "continue" | "undefined" | "error" | "type" | "this" | "unreachable"

ContainerDecl = option("extern" | "packed") ("struct" | "enum" | "union") "{" many(ContainerMember) "}"
```

## Operator Precedence

```
x() x[] x.y
!x -x -%x ~x *x &x ?x %x %%x ??x
x{}
* / % ** *%
+ - ++ +% -%
<< >>
&
^
|
== != < > <= >=
and
or
?? %%
= *= /= %= += -= <<= >>= &= ^= |=
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

## Built-in Functions

Built-in functions are prefixed with `@`. Remember that the `comptime` keyword on
a parameter means that the parameter must be known at compile time.

### @alloca(comptime T: type, count: usize) -> []T

Allocates memory in the stack frame of the caller. This temporary space is
automatically freed when the function that called alloca returns to its caller,
just like other stack variables.

When using this function to allocate memory, you should know the upper bound
of `count`. Consider putting a constant array on the stack with the upper bound
instead of using alloca. If you do use alloca it is to save a few bytes off
the memory size given that you didn't actually hit your upper bound.

The allocated memory contents are undefined.

### @typeOf(expression) -> type

This function returns a compile-time constant, which is the type of the
expression passed as an argument. The expression is *not evaluated*.

### @sizeOf(comptime T: type) -> (number literal)

This function returns the number of bytes it takes to store T in memory.

The result is a target-specific compile time constant.

### @alignOf(comptime T: type) -> (number literal)

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
@addWithOverflow(comptime T: type, a: T, b: T, result: &T) -> bool   *x = a + b
@subWithOverflow(comptime T: type, a: T, b: T, result: &T) -> bool   *x = a - b
@mulWithOverflow(comptime T: type, a: T, b: T, result: &T) -> bool   *x = a * b
@shlWithOverflow(comptime T: type, a: T, b: T, result: &T) -> bool   *x = a << b
```

### @memset(dest: &u8, c: u8, byte_count: usize)

This function sets a region of memory to `c`. `dest` is a pointer.

This function is a low level intrinsic with no safety mechanisms. Most higher
level code will not use this function, instead using something like this:

```zig
for (destSlice) |*b| *b = c;
```

The optimizer is intelligent enough to turn the above snippet into a memset.

### @memcpy(noalias dest: &u8, noalias source: &const u8, byte_count: usize)

This function copies bytes from one region of memory to another. `dest` and
`source` are both pointers and must not overlap.

This function is a low level intrinsic with no safety mechanisms. Most higher
level code will not use this function, instead using something like this:

```zig
const mem = @import("std").mem;
mem.copy(destSlice, sourceSlice);
```

The optimizer is intelligent enough to turn the above snippet into a memcpy.

### @breakpoint()

This function inserts a platform-specific debug trap instruction which causes
debuggers to break there.

This function is only valid within function scope.

### @returnAddress()

This function returns a pointer to the return address of the current stack
frame.

The implications of this are target specific and not consistent across
all platforms.

This function is only valid within function scope.

### @frameAddress()

This function returns the base pointer of the current stack frame.

The implications of this are target specific and not consistent across all
platforms. The frame address may not be available in release mode due to
aggressive optimizations.

This function is only valid within function scope.

### @maxValue(comptime T: type) -> (number literal)

This function returns the maximum integer value of the integer type T.

The result is a compile time constant. For some types such as `c_long`, the
result is marked as depending on a compile variable.

### @minValue(comptime T: type) -> (number literal)

This function returns the minimum integer value of the integer type T.

The result is a compile time constant. For some types such as `c_long`, the
result is marked as depending on a compile variable.

### @memberCount(comptime T: type) -> (number literal)

This function returns the number of enum values in an enum type.

The result is a compile time constant.

### @import(comptime path: []u8) -> (namespace)

This function finds a zig file corresponding to `path` and imports all the
public top level declarations into the resulting namespace.

`path` can be a relative or absolute path, or it can be the name of a package,
such as "std".

This function is only valid at top level scope.

### @cImport(expression) -> (namespace)

This function parses C code and imports the functions, types, variables, and
compatible macro definitions into the result namespace.

`expression` is interpreted at compile time. The builtin functions
`@c_include`, `@c_define`, and `@c_undef` work within this expression,
appending to a temporary buffer which is then parsed as C code.

This function is only valid at top level scope.

### @cInclude(comptime path: []u8)

This function can only occur inside `@c_import`.

This appends `#include <$path>\n` to the `c_import` temporary buffer.

### @cDefine(comptime name: []u8, value)

This function can only occur inside `@c_import`.

This appends `#define $name $value` to the `c_import` temporary buffer.

### @cUndef(comptime name: []u8)

This function can only occur inside `@c_import`.

This appends `#undef $name` to the `c_import` temporary buffer.

### @compileVar(comptime name: []u8) -> (varying type)

This function returns a compile-time variable. There are built in compile
variables:

 * "is_big_endian" `bool` - either `true` for big endian or `false` for little endian.
 * "is_release" `bool`- either `true` for release mode builds or `false` for debug mode builds.
 * "is_test" `bool`- either `true` for test builds or `false` otherwise.
 * "os" `Os` - use `zig targets` to see what enum values are possible here.
 * "arch" `Arch` - use `zig targets` to see what enum values are possible here.
 * "environ" `Environ` - use `zig targets` to see what enum values are possible here.

Build scripts can set additional compile variables of any name and type.

The result of this function is a compile time constant that is marked as
depending on a compile variable.

### @generatedCode(expression) -> @typeOf(expression)

This function wraps an expression and returns the result of the expression
unmodified.

Inside the expression, code is considered generated, which means that the
following compile errors are disabled:

 * unnecessary if statement error

The result of the expression is marked as depending on a compile variable.

### @ctz(x: T) -> T

This function counts the number of trailing zeroes in x which is an integer
type T.

### @clz(x: T) -> T

This function counts the number of leading zeroes in x which is an integer
type T.

### @errorName(err: error) -> []u8

This function returns the string representation of an error. If an error
declaration is:

```zig
error OutOfMem;
```

Then the string representation is "OutOfMem".

If there are no calls to `@errorName` in an entire application, then no error
name table will be generated.

### @typeName(T: type) -> []u8

This function returns the string representation of a type.

### @embedFile(comptime path: []u8) -> [X]u8

This function returns a compile time constant fixed-size array with length
equal to the byte count of the file given by `path`. The contents of the array
are the contents of the file.

### @cmpxchg(ptr: &T, cmp: T, new: T, success_order: MemoryOrder, fail_order: MemoryOrder) -> bool

This function performs an atomic compare exchange operation.

### @fence(order: MemoryOrder)

The `fence` function is used to introduce happens-before edges between operations.

### @divExact(a: T, b: T) -> T

This function performs integer division `a / b` and returns the result.

The caller guarantees that this operation will have no remainder.

In debug mode, a remainder causes a panic. In release mode, a remainder is
undefined behavior.

### @truncate(comptime T: type, integer) -> T

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

This function always truncates the significant bits of the integer, regardless
of endianness on the target platform.

This function also performs a twos complement cast. For example, the following
produces a crash in debug mode and undefined behavior in release mode:

```zig
const a = i16(-1);
const b = u16(a);
```

However this is well defined and working code:

```zig
const a = i16(-1);
const b = @truncate(u16, a);
// b is now 0xffff
```

### @compileError(comptime msg: []u8)

This function, when semantically analyzed, causes a compile error with the
message `msg`.

There are several ways that code avoids being semantically checked, such as
using `if` or `switch` with compile time constants, and comptime functions.

### @compileLog(args: ...)

This function, when semantically analyzed, causes a compile error, but it does
not prevent compile-time code from continuing to run, and it otherwise does not
interfere with analysis.

Each of the arguments will be serialized to a printable debug value and output
to stderr, and then a newline at the end.

This function can be used to do "printf debugging" on compile-time executing
code.

### @intType(comptime is_signed: bool, comptime bit_count: u8) -> type

This function returns an integer type with the given signness and bit count.

### @setDebugSafety(scope, safety_on: bool)

Sets a whether we want debug safety checks on for a given scope.

### @isInteger(comptime T: type) -> bool

Returns whether a given type is an integer.

### @isFloat(comptime T: type) -> bool

Returns whether a given type is a float.

### @canImplicitCast(comptime T: type, value) -> bool

Returns whether a value can be implicitly casted to a given type.

### @setGlobalAlign(global_variable_name, byte_count: usize) -> bool

Sets the alignment property of a global variable.

### @setGlobalSection(global_variable_name, section_name: []u8) -> bool

Puts the global variable in the specified section.

### @panic(message: []const u8) -> noreturn

Invokes the panic handler function. By default the panic handler function
calls the public `panic` function exposed in the root source file, or
if there is not one specified, invokes the one provided in
`std/special/panic.zig`.

### @ptrcast(comptime DestType: type, value: var) -> DestType

Converts a pointer of one type to a pointer of another type.
