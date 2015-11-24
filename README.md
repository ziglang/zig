# zig lang

An experiment in writing a low-level programming language with the intent to
replace C. Zig intends to be a small language, yet powerful enough to write
readable, safe, optimal, and concise code to solve any computing problem.

## Design Principles

 * Never compromise power or performance.
 * Keep the language small and easy to understand. C programmers should pretty
   much be able to understand Zig source code without learning anything about
   Zig.
 * Interoperability with C is crucial. Using C libraries should not require
   "Zig bindings".

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
 * Memory zeroed by default, unless you initialize with "uninitialized".

## Roadmap

 * Hello, world.
   - Produce .o file.
 * Produce executable file instead of .o file.
 * Add debugging symbols.
 * Debug/Release mode.
 * C style comments.
 * Unit tests.
 * Simple .so library
 * How should the Widget use case be solved? In Genesis I'm using C++ and inheritance.

### Primitive Numeric Types:

zig    | C equivalent | Description
-------|--------------|-------------------------------
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
 isize |      ssize_t |   signed pointer sized integer
 usize |       size_t | unsigned pointer sized integer

### Grammar

```
Root : many(TopLevelDecl) token(EOF)

TopLevelDecl : FnDef | ExternBlock

ExternBlock : token(Extern) token(LBrace) many(FnProtoDecl) token(RBrace)

FnProto : token(Fn) token(Symbol) ParamDeclList option(token(Arrow) Type)

FnDecl : FnProto token(Semicolon)

FnDef : FnProto Block

ParamDeclList : token(LParen) list(ParamDecl, token(Comma)) token(RParen)

ParamDecl : token(Symbol) token(Colon) Type

Type : token(Symbol) | PointerType

PointerType : token(Star) token(Const) Type  | token(Star) token(Mut) Type

Block : token(LBrace) many(Statement) token(RBrace)

Statement : ExpressionStatement  | ReturnStatement

ExpressionStatement : Expression token(Semicolon)

ReturnStatement : token(Return) Expression token(Semicolon)

Expression : token(Number) | token(String) | FnCall

FnCall : token(Symbol) token(LParen) list(Expression, token(Comma)) token(RParen)
```
