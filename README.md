![ZIG](http://ziglang.org/zig-logo.svg)

A programming language designed for robustness, optimality, and
clarity.

[ziglang.org](http://ziglang.org)

[Documentation](http://ziglang.org/documentation/)

## Feature Highlights

 * Small, simple language. Focus on debugging your application rather than
   debugging your knowledge of your programming language.
 * Ships with a build system that obviates the need for a configure script
   or a makefile. In fact, existing C and C++ projects may choose to depend on
   Zig instead of e.g. cmake.
 * A fresh take on error handling which makes writing correct code easier than
   writing buggy code.
 * Debug mode optimizes for fast compilation time and crashing with a stack trace
   when undefined behavior *would* happen.
 * Release mode produces heavily optimized code. What other projects call
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
 * Mark functions as tests and automatically run them with `zig test`.
 * Friendly toward package maintainers. Reproducible build, bootstrapping
   process carefully documented. Issues filed by package maintainers are
   considered especially important.
 * Cross-compiling is a primary use case.
 * In addition to creating executables, creating a C library is a primary use
   case. You can export an auto-generated .h file.
 * Standard library supports Operating System abstractions for:
   * `x86_64` `linux`
   * Support for all popular operating systems and architectures is planned.
 * For OS development, Zig supports all architectures that LLVM does. All the
   standard library that does not depend on an OS is available to you in
   freestanding mode.

## Community

 * IRC: `#zig` on Freenode.
 * Reddit: [/r/zig](https://www.reddit.com/r/zig)
 * Email list: [ziglang@googlegroups.com](https://groups.google.com/forum/#!forum/ziglang)

## Building

[![Build Status](https://travis-ci.org/zig-lang/zig.svg?branch=master)](https://travis-ci.org/zig-lang/zig)
[![Build status](https://ci.appveyor.com/api/projects/status/4t80mk2dmucrc38i/branch/master?svg=true)](https://ci.appveyor.com/project/andrewrk/zig-d3l86/branch/master)

### Dependencies

#### Build Dependencies

These compile tools must be available on your system and are used to build
the Zig compiler itself:

 * gcc >= 5.0.0 or clang >= 3.6.0
 * cmake >= 2.8.5

#### Library Dependencies

These libraries must be installed on your system, with the development files
available. The Zig compiler links against them.

 * LLVM, Clang, and LLD libraries == 5.x

### Debug / Development Build

If you have gcc or clang installed, you can find out what `ZIG_LIBC_LIB_DIR`,
`ZIG_LIBC_STATIC_LIB_DIR`, and `ZIG_LIBC_INCLUDE_DIR` should be set to
(example below).

For MacOS, `ZIG_LIBC_LIB_DIR` and `ZIG_LIBC_STATIC_LIB_DIR` are unused.

```
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd) -DZIG_LIBC_LIB_DIR=$(dirname $(cc -print-file-name=crt1.o)) -DZIG_LIBC_INCLUDE_DIR=$(echo -n | cc -E -x c - -v 2>&1 | grep -B1 "End of search list." | head -n1 | cut -c 2- | sed "s/ .*//") -DZIG_LIBC_STATIC_LIB_DIR=$(dirname $(cc -print-file-name=crtbegin.o))
make
make install
./zig build --build-file ../build.zig test
```

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
