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
 * Do not depend on libc.
 * First class error code support.
 * Include documentation generator.
 * Eliminate the need for make, cmake, etc.
 * Friendly toward package maintainers.
 * Eliminate the need for C headers (when using zig internally).
 * Ability to declare dependencies as Git URLS with commit locking (can
   provide a tag or sha1).
 * Rust-style enums.
 * Opinionated when it makes life easier.
   - Tab character in source code is a compile error.
   - Whitespace at the end of line is a compile error.
 * Resilient to parsing errors to make IDE integration work well.
 * Source code is UTF-8.

## Roadmap

 * Hello, world.
   - Build AST
   - Code Gen
 * C style comments.
 * Unit tests.
 * Simple .so library
 * How should the Widget use case be solved? In Genesis I'm using C++ and inheritance.
