![ZIG](http://ziglang.org/zig-logo.svg)

A programming language designed for robustness, optimality, and
clarity.

[ziglang.org](http://ziglang.org)

[Documentation](http://ziglang.org/documentation/master/)

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
 * Tagged union type instead of raw unions.
 * Generics so that one can write efficient data structures that work for any
   data type.
 * No header files required. Top level declarations are entirely
   order-independent.
 * Compile-time code execution. Compile-time reflection.
 * Partial compile-time function evaluation with eliminates the need for
   a preprocessor or macros.
 * The binaries produced by Zig have complete debugging information so you can,
   for example, use GDB to debug your software.
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
|i386         | OK           | planned | OK      | OK      | planned |
|x86_64       | OK           | OK      | OK      | OK      | planned |
|arm          | OK           | planned | planned | N/A     | planned |
|aarch64      | OK           | planned | planned | planned | planned |
|bpf          | OK           | planned | planned | N/A     | planned |
|hexagon      | OK           | planned | planned | N/A     | planned |
|mips         | OK           | planned | planned | N/A     | planned |
|powerpc      | OK           | planned | planned | N/A     | planned |
|r600         | OK           | planned | planned | N/A     | planned |
|amdgcn       | OK           | planned | planned | N/A     | planned |
|sparc        | OK           | planned | planned | N/A     | planned |
|s390x        | OK           | planned | planned | N/A     | planned |
|thumb        | OK           | planned | planned | N/A     | planned |
|spir         | OK           | planned | planned | N/A     | planned |
|lanai        | OK           | planned | planned | N/A     | planned |

## Community

 * IRC: `#zig` on Freenode.
 * Reddit: [/r/zig](https://www.reddit.com/r/zig)
 * Email list: [ziglang@googlegroups.com](https://groups.google.com/forum/#!forum/ziglang)

### Wanted: Windows Developers

Help get the tests passing on Windows, flesh out the standard library for
Windows, streamline Zig installation and distribution for Windows. Work with
LLVM and LLD teams to improve PDB/CodeView/MSVC debugging. Implement stack traces
for Windows in the MinGW environment and the MSVC environment.

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

[![Build Status](https://travis-ci.org/zig-lang/zig.svg?branch=master)](https://travis-ci.org/zig-lang/zig)
[![Build status](https://ci.appveyor.com/api/projects/status/4t80mk2dmucrc38i/branch/master?svg=true)](https://ci.appveyor.com/project/andrewrk/zig-d3l86/branch/master)

### Dependencies

#### Build Dependencies

These compile tools must be available on your system and are used to build
the Zig compiler itself:

##### POSIX

 * gcc >= 5.0.0 or clang >= 3.6.0
 * cmake >= 2.8.5

##### Windows

 * Microsoft Visual Studio 2015

#### Library Dependencies

These libraries must be installed on your system, with the development files
available. The Zig compiler links against them. You have to use the same
compiler for these libraries as you do to compile Zig.

 * LLVM, Clang, and LLD libraries == 6.x

### Debug / Development Build

If you have gcc or clang installed, you can find out what `ZIG_LIBC_LIB_DIR`,
`ZIG_LIBC_STATIC_LIB_DIR`, and `ZIG_LIBC_INCLUDE_DIR` should be set to
(example below).

```
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd) -DZIG_LIBC_LIB_DIR=$(dirname $(cc -print-file-name=crt1.o)) -DZIG_LIBC_INCLUDE_DIR=$(echo -n | cc -E -x c - -v 2>&1 | grep -B1 "End of search list." | head -n1 | cut -c 2- | sed "s/ .*//") -DZIG_LIBC_STATIC_LIB_DIR=$(dirname $(cc -print-file-name=crtbegin.o))
make
make install
./zig build --build-file ../build.zig test
```

#### MacOS

`ZIG_LIBC_LIB_DIR` and `ZIG_LIBC_STATIC_LIB_DIR` are unused.

```
brew install llvm@6
brew outdated llvm@6 || brew upgrade llvm@6
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=/usr/local/opt/llvm@6/ -DCMAKE_INSTALL_PREFIX=$(pwd)
make install
./zig build --build-file ../build.zig test
```

#### Windows

See https://github.com/zig-lang/zig/wiki/Building-Zig-on-Windows

### Release / Install Build

Once installed, `ZIG_LIBC_LIB_DIR` and `ZIG_LIBC_INCLUDE_DIR` can be overridden
by the `--libc-lib-dir` and `--libc-include-dir` parameters to the zig binary.

```
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DZIG_LIBC_LIB_DIR=/some/path -DZIG_LIBC_INCLUDE_DIR=/some/path -DZIG_LIBC_STATIC_INCLUDE_DIR=/some/path
make
sudo make install
```

### Test Coverage

To see test coverage in Zig, configure with `-DZIG_TEST_COVERAGE=ON` as an
additional parameter to the Debug build.

You must have `lcov` installed and available.

Then `make coverage`.

With GCC you will get a nice HTML view of the coverage data. With clang,
the last step will fail, but you can execute
`llvm-cov gcov $(find CMakeFiles/ -name "*.gcda")` and then inspect the
produced .gcov files.

### Related Projects

 * [zig-mode](https://github.com/AndreaOrru/zig-mode) - Emacs integration
 * [zig.vim](https://github.com/zig-lang/zig.vim) - Vim configuration files
 * [vscode-zig](https://github.com/zig-lang/vscode-zig) - Visual Studio Code extension
 * [zig-compiler-completions](https://github.com/tiehuis/zig-compiler-completions) - bash and zsh completions for the zig compiler
 * [NppExtension](https://github.com/ice1000/NppExtension) - Notepad++ syntax highlighting
