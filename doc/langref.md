# Language Reference

## Grammar

```
Root : many(TopLevelDecl) "EOF"

TopLevelDecl : FnDef | ExternBlock | RootExportDecl | Import | ContainerDecl | VariableDeclaration

VariableDeclaration : option(FnVisibleMod) ("var" | "const") "symbol" ("=" Expression | ":" PrefixOpExpression option("=" Expression))

ContainerDecl : many(Directive) option(FnVisibleMod) ("struct" | "enum") "Symbol" "{" many(StructMember) "}"

StructMember: StructField | FnDecl

StructField : "Symbol" option(":" Expression) ",")

Import : many(Directive) "import" "String" ";"

RootExportDecl : many(Directive) "export" "Symbol" "String" ";"

ExternBlock : many(Directive) "extern" "{" many(FnDecl) "}"

FnProto : many(Directive) option(FnVisibleMod) "fn" "Symbol" ParamDeclList option(PrefixOpExpression)

Directive : "#" "Symbol" "(" "String" ")"

FnVisibleMod : "pub" | "export"

FnDecl : FnProto ";"

FnDef : FnProto "=>" Block

ParamDeclList : "(" list(ParamDecl, ",") ")"

ParamDecl : option("noalias") "Symbol" ":" PrefixOpExpression | "..."

Block : "{" list(option(Statement), ";") "}"

Statement : Label | VariableDeclaration ";" | NonBlockExpression ";" | BlockExpression

Label: "Symbol" ":"

Expression : BlockExpression | NonBlockExpression

NonBlockExpression : ReturnExpression | AssignmentExpression

AsmExpression : "asm" option("volatile") "(" "String" option(AsmOutput) ")"

AsmOutput : ":" list(AsmOutputItem, ",") option(AsmInput)

AsmInput : ":" list(AsmInputItem, ",") option(AsmClobbers)

AsmOutputItem : "[" "Symbol" "]" "String" "(" ("Symbol" | "->" PrefixOpExpression) ")"

AsmInputItem : "[" "Symbol" "]" "String" "(" Expression ")"

AsmClobbers: ":" list("String", ",")

UnwrapMaybeExpression : BoolOrExpression "??" BoolOrExpression | BoolOrExpression

AssignmentExpression : UnwrapMaybeExpression AssignmentOperator UnwrapMaybeExpression | UnwrapMaybeExpression

AssignmentOperator : "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "^=" | "|=" | "&&=" | "||="

BlockExpression : IfExpression | Block | WhileExpression | ForExpression | SwitchExpression

SwitchExpression : "switch" "(" Expression ")" "{" many(SwitchProng) "}"

SwitchProng : (list(SwitchItem, ",") | "else") option(":" "(" "Symbol" ")") "=>" Expression ","

SwitchItem : Expression | (Expression "..." Expression)

WhileExpression : "while" "(" Expression ")" Expression

ForExpression : "for" "(" "Symbol" "," Expression option("," "Symbol") ")" Expression

BoolOrExpression : BoolAndExpression "||" BoolOrExpression | BoolAndExpression

ReturnExpression : "return" option(Expression)

IfExpression : IfVarExpression | IfBoolExpression

IfBoolExpression : "if" "(" Expression ")" Expression option(Else)

IfVarExpression : "if" "(" ("const" | "var") "Symbol" option(":" PrefixOpExpression) "?=" Expression ")" Expression Option(Else)

Else : "else" Expression

BoolAndExpression : ComparisonExpression "&&" BoolAndExpression | ComparisonExpression

ComparisonExpression : BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression

ComparisonOperator : "==" | "!=" | "<" | ">" | "<=" | ">="

BinaryOrExpression : BinaryXorExpression "|" BinaryOrExpression | BinaryXorExpression

BinaryXorExpression : BinaryAndExpression "^" BinaryXorExpression | BinaryAndExpression

BinaryAndExpression : BitShiftExpression "&" BinaryAndExpression | BitShiftExpression

BitShiftExpression : AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression

BitShiftOperator : "<<" | ">>"

AdditionExpression : MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression

AdditionOperator : "+" | "-"

MultiplyExpression : CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression

CurlySuffixExpression : PrefixOpExpression option(ContainerInitExpression)

MultiplyOperator : "*" | "/" | "%"

PrefixOpExpression : PrefixOp PrefixOpExpression | SuffixOpExpression

SuffixOpExpression : PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)

FieldAccessExpression : "." "Symbol"

FnCallExpression : "(" list(Expression, ",") ")"

ArrayAccessExpression : "[" Expression "]"

SliceExpression : "[" Expression "..." option(Expression) "]" option("const")

ContainerInitExpression : "{" ContainerInitBody "}"

ContainerInitBody : list(StructLiteralField, ",") | list(Expression, ",")

StructLiteralField : "." "Symbol" "=" Expression

PrefixOp : "!" | "-" | "~" | "*" | ("&" option("const")) | "?"

PrimaryExpression : "Number" | "String" | "CharLiteral" | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression | "Symbol" | ("@" "Symbol" FnCallExpression) | ArrayType | AsmExpression

ArrayType : "[" option(Expression) "]" option("const") PrefixOpExpression

GotoExpression: "goto" "Symbol"

GroupedExpression : "(" Expression ")"

KeywordLiteral : "true" | "false" | "null" | "break" | "continue"
```

## Operator Precedence

```
x() x[] x.y
!x -x ~x *x &x ?x
x{}
* / %
+ -
<< >>
&
^
|
== != < > <= >=
&&
||
??
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

f32             float               32-bit IEE754 floating point
f64             double              64-bit IEE754 floating point
f128            long double         128-bit IEE754 floating point

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
```

### Boolean Type
The boolean type has the name `bool` and represents either true or false.

### Function Types
TODO

### Array Types
TODO
Also, are there slices?

### Struct Types
TODO

### Pointer Types
TODO

### Unreachable Type
The unreachable type has the name `unreachable`. TODO explanation

### Void Type
The void type has the name `void`. TODO explanation


## Expressions

### Literals

#### Character and String Literals
```
Literal         Example   Characters   Escapes         Null Term  Type

Byte            'H'       All ASCII    Byte            No         u8
UTF-8 Bytes     "hello"   All Unicode  Byte & Unicode  No         [5]u8
UTF-8 C string  c"hello"  All Unicode  Byte & Unicode  Yes        &const u8
```

```
Escape  Name

\xNN    hexadecimal 8-bit character code (exactly 2 digits)
\n      Newline
\r      Carriage return
\t      Tab
\\      Backslash
\0      Null
\'      Single quote
\"      Double quote
```

### Unicode Escapes

 Escape     | Name
------------|-----------------------------------------------
 \u{NNNNNN} | hexadecimal 24-bit Unicode character code (up to 6 digits)

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

### Typeof
TODO

### Sizeof
TODO

### Overflow Arithmetic
Overflow arithmetic functions have defined behavior on overflow or underflow. TODO what is that behaviour?

The functions take an integer (TODO float?) type, two variables of the specified type, and a pointer to a variable of the specified type where the result is stored. The functions return a boolean value: true of overflow/underflow occurred, false otherwise.

```
Function                                                  Operation
bool add_with_overflow(type, a: type, b: type, x: &type)  *x = a + b
bool sub_with_overflow(type, a: type, b: type, x: &type)  *x = a - b
bool mul_with_overflow(type, a: type, b: type, x: &type)  *x = a * b
```

### Memory Operations
TODO memset and memcpy

### Value Count
TODO

### Max and Min Value
TODO
