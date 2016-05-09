# Language Reference

## Grammar

```
Root = many(TopLevelDecl) "EOF"

TopLevelDecl = many(Directive) option(VisibleMod) (FnDef | ExternDecl | ContainerDecl | GlobalVarDecl | ErrorValueDecl | TypeDecl | UseDecl)

TypeDecl = "type" "Symbol" "=" TypeExpr ";"

ErrorValueDecl = "error" "Symbol" ";"

GlobalVarDecl = VariableDeclaration ";"

VariableDeclaration = ("var" | "const") "Symbol" option(":" TypeExpr) "=" Expression

ContainerDecl = ("struct" | "enum" | "union") "Symbol" option(ParamDeclList) "{" many(StructMember) "}"

StructMember = many(Directive) option(VisibleMod) (StructField | FnDef | GlobalVarDecl | ContainerDecl)

StructField = "Symbol" option(":" Expression) ",")

UseDecl = "use" Expression ";"

ExternDecl = "extern" (FnProto | VariableDeclaration) ";"

FnProto = "fn" option("Symbol") option(ParamDeclList) ParamDeclList option("->" TypeExpr)

Directive = "#" "Symbol" "(" Expression ")"

VisibleMod = "pub" | "export"

FnDef = option("inline" | "extern") FnProto Block

ParamDeclList = "(" list(ParamDecl, ",") ")"

ParamDecl = option("noalias") option("Symbol" ":") TypeExpr | "..."

Block = "{" list(option(Statement), ";") "}"

Statement = Label | VariableDeclaration ";" | Defer ";" | NonBlockExpression ";" | BlockExpression

Label = "Symbol" ":"

Expression = BlockExpression | NonBlockExpression

TypeExpr = PrefixOpExpression

NonBlockExpression = ReturnExpression | AssignmentExpression

AsmExpression = "asm" option("volatile") "(" "String" option(AsmOutput) ")"

AsmOutput = ":" list(AsmOutputItem, ",") option(AsmInput)

AsmInput = ":" list(AsmInputItem, ",") option(AsmClobbers)

AsmOutputItem = "[" "Symbol" "]" "String" "(" ("Symbol" | "->" TypeExpr) ")"

AsmInputItem = "[" "Symbol" "]" "String" "(" Expression ")"

AsmClobbers= ":" list("String", ",")

UnwrapExpression = BoolOrExpression (UnwrapMaybe | UnwrapError) | BoolOrExpression

UnwrapMaybe = "??" Expression

UnwrapError = "%%" option("|" "Symbol" "|") Expression

AssignmentExpression = UnwrapExpression AssignmentOperator UnwrapExpression | UnwrapExpression

AssignmentOperator = "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "^=" | "|=" | "&&=" | "||="

BlockExpression = IfExpression | Block | WhileExpression | ForExpression | SwitchExpression

SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"

SwitchProng = (list(SwitchItem, ",") | "else") "=>" option("|" "Symbol" "|") Expression ","

SwitchItem = Expression | (Expression "..." Expression)

WhileExpression = "while" "(" Expression option(";" Expression) ")" Expression

ForExpression = "for" "(" Expression ")" option("|" option("*") "Symbol" option("," "Symbol") "|") Expression

BoolOrExpression = BoolAndExpression "||" BoolOrExpression | BoolAndExpression

ReturnExpression = option("%" | "?") "return" option(Expression)

Defer = option("%" | "?") "defer" option(Expression)

IfExpression = IfVarExpression | IfBoolExpression

IfBoolExpression = "if" "(" Expression ")" Expression option(Else)

IfVarExpression = "if" "(" ("const" | "var") option("*") "Symbol" option(":" TypeExpr) "?=" Expression ")" Expression Option(Else)

Else = "else" Expression

BoolAndExpression = ComparisonExpression "&&" BoolAndExpression | ComparisonExpression

ComparisonExpression = BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression

ComparisonOperator = "==" | "!=" | "<" | ">" | "<=" | ">="

BinaryOrExpression = BinaryXorExpression "|" BinaryOrExpression | BinaryXorExpression

BinaryXorExpression = BinaryAndExpression "^" BinaryXorExpression | BinaryAndExpression

BinaryAndExpression = BitShiftExpression "&" BinaryAndExpression | BitShiftExpression

BitShiftExpression = AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression

BitShiftOperator = "<<" | ">>"

AdditionExpression = MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression

AdditionOperator = "+" | "-" | "++"

MultiplyExpression = CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression

CurlySuffixExpression = TypeExpr option(ContainerInitExpression)

MultiplyOperator = "*" | "/" | "%" | "**"

PrefixOpExpression = PrefixOp PrefixOpExpression | SuffixOpExpression

SuffixOpExpression = PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)

FieldAccessExpression = "." "Symbol"

FnCallExpression = "(" list(Expression, ",") ")"

ArrayAccessExpression = "[" Expression "]"

SliceExpression = "[" Expression "..." option(Expression) "]" option("const")

ContainerInitExpression = "{" ContainerInitBody "}"

ContainerInitBody = list(StructLiteralField, ",") | list(Expression, ",")

StructLiteralField = "." "Symbol" "=" Expression

PrefixOp = "!" | "-" | "~" | "*" | ("&" option("const")) | "?" | "%" | "%%" | "??"

PrimaryExpression = "Number" | "String" | "CharLiteral" | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression | "Symbol" | ("@" "Symbol" FnCallExpression) | ArrayType | (option("extern") FnProto) | AsmExpression | ("error" "." "Symbol")

ArrayType = "[" option(Expression) "]" option("const") TypeExpr

GotoExpression = "goto" "Symbol"

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
u8              (none)              unsigned 8-bit integer
i16             int16_t             signed 16-bit integer
u16             (none)              unsigned 16-bit integer
i32             int32_t             signed 32-bit integer
u32             (none)              unsigned 32-bit integer
i64             int64_t             signed 64-bit integer
u64             (none)              unsigned 64-bit integer
isize           intptr_t            signed pointer sized integer
usize           (none)              unsigned pointer sized integer

i8w             (none)              wrapping signed 8-bit integer
u8w             uint8_t             wrapping unsigned 8-bit integer
i16w            (none)              wrapping signed 16-bit integer
u16w            uint16_t            wrapping unsigned 16-bit integer
i32w            (none)              wrapping signed 32-bit integer
u32w            uint32_t            wrapping unsigned 32-bit integer
i64w            (none)              wrapping signed 64-bit integer
u64w            uint64_t            wrapping unsigned 64-bit integer
isizew          (none)              wrapping signed pointer sized integer
usizew          uintptr_t           wrapping unsigned pointer sized integer

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

f32             float               32-bit IEE754 floating point
f64             double              64-bit IEE754 floating point
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
UTF-8 Raw String   r"X(hello)X"  All Unicode  None            No         [5]u8
UTF-8 Raw C String rc"X(hello)X" All Unicode  None            Yes        &const u8
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

##### Raw Strings

Raw string literals have no escapes and can span across multiple lines. To
start a raw string, use 'r"' or 'rc"' followed by unique bytes followed by '('.
To end a raw string, use ')' followed by the same unique bytes, followed by '"'.


#### Numeric Literals

```
Number literals     Example      Exponentiation

Decimal integer     98222        N/A
Hex integer         0xff         N/A
Octal integer       0o77         N/A
Binary integer      0b11110000   N/A
Floating-point      123.0E+77    Optional
Hex floating point  TODO         TODO
```

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

Built-in functions are prefixed with `@`.

### @typeof

`@typeof(expression)`

### @sizeof

`@sizeof(type)`

### Overflow Arithmetic

Overflow arithmetic functions have defined behavior on overflow or underflow.

The functions take an integer type, two variables of the specified type, and a
pointer to a variable of the specified type where the result is stored. The
functions return a boolean value: true of overflow/underflow occurred, false
otherwise.

```
Function                                                  Operation
@add_with_overflow(T: type, a: T, b: T, x: &T) -> bool    *x = a + b
@sub_with_overflow(T: type, a: T, b: T, x: &T) -> bool    *x = a - b
@mul_with_overflow(T: type, a: T, b: T, x: &T) -> bool    *x = a * b
```

### @memset

`@memset(dest, char, len)`

### @memcpy

`@memcpy(dest, source, len)`

### @member_count

`@member_count(enum_type)`

### Max and Min Value

`@max_value(type)`
`@min_value(type)`
