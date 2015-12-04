# zig lang

An experiment in writing a low-level programming language with the intent to
replace C. Zig intends to be a small language, yet powerful enough to write
readable, safe, optimal, and concise code to solve any computing problem.

## Goals

 * Ability to run arbitrary code at compile time and generate code.
 * Completely compatible with C libraries with no wrapper necessary.
 * Creating a C library should be a primary use case. Should be easy to export
   an auto-generated .h file.
 * Generics such as containers.
 * Do not depend on libc unless explicitly imported.
 * First class error code support.
 * Include documentation generator.
 * Eliminate the need for make, cmake, etc.
 * Friendly toward package maintainers.
 * Eliminate the need for C headers (when using zig internally).
 * Ability to declare dependencies as Git URLS with commit locking (can
   provide a tag or sha1).
 * Tagged union enum type.
 * Opinionated when it makes life easier.
   - Tab character in source code is a compile error.
   - Whitespace at the end of line is a compile error.
 * Resilient to parsing errors to make IDE integration work well.
 * Source code is UTF-8.
 * Shebang line OK so language can be used for "scripting" as well.
 * Ability to mark functions as test and automatically run them in test mode.
   This mode should automatically provide test coverage.
 * Memory zeroed by default, unless you initialize with "uninitialized".

### Building

```
mkdir build
cd build
cmake ..
make
./run_tests
```

## Roadmap

 * unreachable <--> noreturn attribute
 * unused label error
 * loops
 * structs
 * tagged enums
 * calling external variadic functions and exporting variadic functions
 * inline assembly and syscalls
 * conditional compilation and ability to check target platform and architecture
 * main function with command line arguments
 * running code at compile time
 * print! macro that takes var args
 * panic! macro that prints a stack trace to stderr in debug mode and calls
   abort() in release mode
 * unreachable codegen to panic("unreachable") in debug mode, and nothing in
   release mode
 * implement a simple game using SDL2
 * How should the Widget use case be solved? In Genesis I'm using C++ and inheritance.

### Primitive Numeric Types:

zig    | C equivalent | Description
-------|--------------|-------------------------------
  bool |         bool |  unsigned 1-bit integer
    i8 |       int8_t |    signed 8-bit integer
    u8 |      uint8_t |  unsigned 8-bit integer
   i16 |      int16_t |   signed 16-bit integer
   u16 |     uint16_t | unsigned 16-bit integer
   i32 |      int32_t |   signed 32-bit integer
   u32 |     uint32_t | unsigned 32-bit integer
   i64 |      int64_t |   signed 64-bit integer
   u64 |     uint64_t | unsigned 64-bit integer
   f32 |        float |  32-bit IEE754 floating point
   f64 |       double |  64-bit IEE754 floating point
  f128 |  long double | 128-bit IEE754 floating point
 isize |     intptr_t |   signed pointer sized integer
 usize |    uintptr_t | unsigned pointer sized integer

### Grammar

```
Root : many(TopLevelDecl) token(EOF)

TopLevelDecl : FnDef | ExternBlock | RootExportDecl | Use

Use : many(Directive) token(Use) token(String) token(Semicolon)

RootExportDecl : many(Directive) token(Export) token(Symbol) token(String) token(Semicolon)

ExternBlock : many(Directive) token(Extern) token(LBrace) many(FnDecl) token(RBrace)

FnProto : many(Directive) option(FnVisibleMod) token(Fn) token(Symbol) ParamDeclList option(token(Arrow) Type)

Directive : token(NumberSign) token(Symbol) token(LParen) token(String) token(RParen)

FnVisibleMod : token(Pub) | token(Export)

FnDecl : FnProto token(Semicolon)

FnDef : FnProto Block

ParamDeclList : token(LParen) list(ParamDecl, token(Comma)) token(RParen)

ParamDecl : token(Symbol) token(Colon) Type

Type : token(Symbol) | PointerType | token(Unreachable)

PointerType : token(Star) token(Const) Type | token(Star) token(Mut) Type

Block : token(LBrace) list(option(Statement), token(Semicolon)) token(RBrace)

Statement : Label | NonBlockExpression token(Semicolon) | BlockExpression

Label: token(Symbol) token(Colon)

Expression : BlockExpression | NonBlockExpression

NonBlockExpression : ReturnExpression | VariableDeclaration | BoolOrExpression

BlockExpression : IfExpression | Block

BoolOrExpression : BoolAndExpression token(BoolOr) BoolAndExpression | BoolAndExpression

ReturnExpression : token(Return) option(Expression)

VariableDeclaration : token(Let) token(Symbole) (token(Eq) Expression | token(Colon) Type option(token(Eq) Expression))

IfExpression : token(If) Expression Block option(Else | ElseIf)

ElseIf : token(Else) IfExpression

Else : token(Else) Block

BoolAndExpression : ComparisonExpression token(BoolAnd) ComparisonExpression | ComparisonExpression

ComparisonExpression : BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression

ComparisonOperator : token(BoolEq) | token(BoolNotEq) | token(BoolLessThan) | token(BoolGreaterThan) | token(BoolLessEqual) | token(BoolGreaterEqual)

BinaryOrExpression : BinaryXorExpression token(BinOr) BinaryXorExpression | BinaryXorExpression

BinaryXorExpression : BinaryAndExpression token(BinXor) BinaryAndExpression | BinaryAndExpression

BinaryAndExpression : BitShiftExpression token(BinAnd) BitShiftExpression | BitShiftExpression

BitShiftExpression : AdditionExpression BitShiftOperator AdditionExpression | AdditionExpression

BitShiftOperator : token(BitShiftLeft | token(BitShiftRight)

AdditionExpression : MultiplyExpression AdditionOperator MultiplyExpression | MultiplyExpression

AdditionOperator : token(Plus) | token(Minus)

MultiplyExpression : CastExpression MultiplyOperator CastExpression | CastExpression

MultiplyOperator : token(Star) | token(Slash) | token(Percent)

CastExpression : PrefixOpExpression token(as) Type | PrefixOpExpression

PrefixOpExpression : PrefixOp FnCallExpression | FnCallExpression

FnCallExpression : PrimaryExpression token(LParen) list(Expression, token(Comma)) token(RParen) | PrimaryExpression

PrefixOp : token(Not) | token(Dash) | token(Tilde)

PrimaryExpression : token(Number) | token(String) | KeywordLiteral | GroupedExpression | token(Symbol) | Goto

Goto: token(Goto) token(Symbol)

GroupedExpression : token(LParen) Expression token(RParen)

KeywordLiteral : token(Unreachable) | token(Void) | token(True) | token(False)
```

### Operator Precedence

```
x()
!x -x ~x
as
* / %
+ -
<< >>
&
^
|
== != < > <= >=
&&
||
=
```
