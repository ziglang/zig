![ZIG](https://ziglang.org/zig-logo.svg)

A programming language designed for robustness, optimality, and
clarity.

[ziglang.org](https://ziglang.org)

## Feature Highlights

 * Small, simple language. Focus on debugging your application rather than
   debugging knowledge of your programming language.
 * Ships with a build system that obviates the need for a configure script
   or a makefile. In fact, existing C and C++ projects may choose to depend on
   Zig instead of e.g. cmake.
 * A fresh take on error handling which makes writing correct code easier than
   writing buggy code.
 * Debug mode optimizes for fast compilation time and crashing with a stack trace
   when undefined behavior *would* happen.
 * ReleaseFast mode produces heavily optimized code. What other projects call
   "Link Time Optimization" Zig does automatically.
 * Compatible with C libraries with no wrapper necessary. Directly include
   C .h files and get access to the functions and symbols therein.
 * Provides standard library which competes with the C standard library and is
   always compiled against statically in source form. Compile units do not
   depend on libc unless explicitly linked.
 * Nullable type instead of null pointers.
 * Safe unions, tagged unions, and C ABI compatible unions.
 * Generics so that one can write efficient data structures that work for any
   data type.
 * No header files required. Top level declarations are entirely
   order-independent.
 * Compile-time code execution. Compile-time reflection.
 * Partial compile-time function evaluation with eliminates the need for
   a preprocessor or macros.
 * The binaries produced by Zig have complete debugging information so you can,
   for example, use GDB or MSVC to debug your software.
 * Built-in unit tests with `zig test`.
 * Friendly toward package maintainers. Reproducible build, bootstrapping
   process carefully documented. Issues filed by package maintainers are
   considered especially important.
 * Cross-compiling is a primary use case.
 * In addition to creating executables, creating a C library is a primary use
   case. You can export an auto-generated .h file.

### Support Table

Freestanding means that you do not directly interact with the OS
or you are writing your own OS.

Note that if you use libc or other libraries to interact with the OS,
that counts as "freestanding" for the purposes of this table.

|             | freestanding | linux   | macosx  | windows | other   |
|-------------|--------------|---------|---------|---------|---------|
|i386         | OK           | planned | OK      | planned | planned |
|x86_64       | OK           | OK      | OK      | OK      | planned |
|arm          | OK           | planned | planned | N/A     | planned |
|aarch64      | OK           | planned | N/A     | planned | planned |
|bpf          | OK           | planned | N/A     | N/A     | planned |
|hexagon      | OK           | planned | N/A     | N/A     | planned |
|mips         | OK           | planned | N/A     | N/A     | planned |
|powerpc      | OK           | planned | N/A     | N/A     | planned |
|r600         | OK           | planned | N/A     | N/A     | planned |
|amdgcn       | OK           | planned | N/A     | N/A     | planned |
|sparc        | OK           | planned | N/A     | N/A     | planned |
|s390x        | OK           | planned | N/A     | N/A     | planned |
|thumb        | OK           | planned | N/A     | N/A     | planned |
|spir         | OK           | planned | N/A     | N/A     | planned |
|lanai        | OK           | planned | N/A     | N/A     | planned |

## Community

 * IRC: `#zig` on Freenode.
 * Reddit: [/r/zig](https://www.reddit.com/r/zig)
 * Email list: [ziglang@googlegroups.com](https://groups.google.com/forum/#!forum/ziglang)

### Wanted: Windows Developers

Flesh out the standard library for Windows, streamline Zig installation and
distribution for Windows. Work with LLVM and LLD teams to improve
PDB/CodeView/MSVC debugging. Implement stack traces for Windows in the MinGW
environment and the MSVC environment.

### Wanted: MacOS and iOS Developers

Flesh out the standard library for MacOS. Improve the MACH-O linker. Implement
stack traces for MacOS. Streamline the process of using Zig to build for
iOS.

### Wanted: Android Developers

Flesh out the standard library for Android. Streamline the process of using
Zig to build for Android and for depending on Zig code on Android.

### Wanted: Web Developers

Figure out what are the use cases for compiling Zig to WebAssembly. Create demo
projects with it and streamline experience for users trying to output
WebAssembly. Work on the documentation generator outputting useful searchable html
documentation. Create Zig modules for common web tasks such as WebSockets and gzip.

### Wanted: Embedded Developers

Flesh out the standard library for uncommon CPU architectures and OS targets.
Drive issue discussion for cross compiling and using Zig in constrained
or unusual environments.

### Wanted: Game Developers

Create cross platform Zig modules to compete with SDL and GLFW. Create an
OpenGL library that does not depend on libc. Drive the usability of Zig
for video games. Create a general purpose allocator that does not depend on
libc. Create demo games using Zig.

## Building

[![Build Status](https://travis-ci.org/ziglang/zig.svg?branch=master)](https://travis-ci.org/ziglang/zig)
[![Build status](https://ci.appveyor.com/api/projects/status/4t80mk2dmucrc38i/branch/master?svg=true)](https://ci.appveyor.com/project/andrewrk/zig-d3l86/branch/master)

### Stage 1: Build Zig from C++ Source Code

#### Dependencies

##### POSIX

 * cmake >= 2.8.5
 * gcc >= 5.0.0 or clang >= 3.6.0
 * LLVM, Clang, LLD development libraries == 6.x, compiled with the same gcc or clang version above
   - These depend on zlib and libxml2.

##### Windows

 * cmake >= 2.8.5
 * Microsoft Visual Studio 2015
 * LLVM, Clang, LLD development libraries == 6.x, compiled with the same MSVC version above

#### Instructions

##### POSIX

```
mkdir build
cd build
cmake ..
make
make install
bin/zig build --build-file ../build.zig test
```

##### MacOS

```
brew install cmake llvm@6
brew outdated llvm@6 || brew upgrade llvm@6
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=/usr/local/opt/llvm@6/
make install
bin/zig build --build-file ../build.zig test
```

##### Windows

See https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows

### Stage 2: Build Self-Hosted Zig from Zig Source Code

*Note: Stage 2 compiler is not complete. Beta users of Zig should use the
Stage 1 compiler for now.*

Dependencies are the same as Stage 1, except now you have a working zig compiler.

```
bin/zig build --build-file ../build.zig --prefix $(pwd)/stage2 install
```

This produces `./stage2/bin/zig` which can be used for testing and development.
Once it is feature complete, it will be used to build stage 3 - the final compiler
binary.

### Stage 3: Rebuild Self-Hosted Zig Using the Self-Hosted Compiler

This is the actual compiler binary that we will install to the system.

*Note: Stage 2 compiler is not yet able to build Stage 3. Building Stage 3 is
not yet supported.*

#### Debug / Development Build

```
./stage2/bin/zig build --build-file ../build.zig --prefix $(pwd)/stage3 install
```

#### Release / Install Build

```
./stage2/bin/zig build --build-file ../build.zig install -Drelease-fast
```
