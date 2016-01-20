# Language Reference

## Primitive Numeric Types:

zig          |        C equivalent    | Description
-------------|------------------------|-------------------------------
        bool |                   bool |  unsigned 1-bit integer
          i8 |                 int8_t |    signed 8-bit integer
          u8 |                uint8_t |  unsigned 8-bit integer
         i16 |                int16_t |   signed 16-bit integer
         u16 |               uint16_t | unsigned 16-bit integer
         i32 |                int32_t |   signed 32-bit integer
         u32 |               uint32_t | unsigned 32-bit integer
         i64 |                int64_t |   signed 64-bit integer
         u64 |               uint64_t | unsigned 64-bit integer
         f32 |                  float |  32-bit IEE754 floating point
         f64 |                 double |  64-bit IEE754 floating point
        f128 |            long double | 128-bit IEE754 floating point
       isize |               intptr_t |   signed pointer sized integer
       usize |              uintptr_t | unsigned pointer sized integer
     c_short |                  short | for API compatibility with C
    c_ushort |         unsigned short | for API compatibility with C
       c_int |                    int | for API compatibility with C
      c_uint |           unsigned int | for API compatibility with C
      c_long |                   long | for API compatibility with C
     c_ulong |          unsigned long | for API compatibility with C
  c_longlong |              long long | for API compatibility with C
 c_ulonglong |     unsigned long long | for API compatibility with C

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

SwitchProng : (list(SwitchItem, ",") | "else") option("," "(" "Symbol" ")") "=>" Expression ","

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

## Literals

### Characters and Strings

                | Example  | Characters  | Escapes        | Null Term | Type
----------------|----------|-------------|----------------|-----------|----------
 Byte           | 'H'      | All ASCII   | Byte           | No        | u8
 UTF-8 Bytes    | "hello"  | All Unicode | Byte & Unicode | No        | [5; u8]
 UTF-8 C string | c"hello" | All Unicode | Byte & Unicode | Yes       | *const u8

### Byte Escapes

      | Name
------|----------------------------------------
 \x7F | 8-bit character code (exactly 2 digits)
 \n   | Newline
 \r   | Carriage return
 \t   | Tab
 \\   | Backslash
 \0   | Null
 \'   | Single quote
 \"   | Double quote

### Unicode Escapes

          | Name
----------|-----------------------------------------------
 \u{7FFF} | 24-bit Unicode character code (up to 6 digits)

### Numbers

 Number literals    | Example     | Exponentiation
--------------------|-------------|---------------
 Decimal integer    | 98222       | N/A
 Hex integer        | 0xff        | N/A
 Octal integer      | 0o77        | N/A
 Binary integer     | 0b11110000  | N/A
 Floating-point     | 123.0E+77   | Optional
 Hex floating point | TODO        | TODO
