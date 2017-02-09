![ZIG](http://ziglang.org/zig-logo.svg)

A system programming language which prioritizes optimality, safety, and
readability.

Zig is a small language, yet powerful enough to solve any computing problem.

Zig intends to replace C. Therefore, porting a C project to Zig should be a
pleasant experience. For every use case C can solve, the same use case must
be handled in Zig in an equally or more satisfying way.

Zig is not afraid to roll the major version number of the language if it
improves simplicity, fixes poor design decisions, or adds a new feature which
compromises backward compatibility.

[ziglang.org](http://ziglang.org)

## Existing Features

 * Compatible with C libraries with no wrapper necessary. Directly include
   C .h files and get access to the functions and symbols therein.
 * Compile units do not depend on libc unless explicitly linked.
 * Provides standard library which competes with the C standard library and is
   always compiled against statically in source form.
 * Pointer types do not allow the null value. Instead you can use a maybe type
   which has several syntactic constructs to ensure that the null pointer is
   not missed.
 * Provides an error type with several syntatic constructs which makes writing
   robust code convenient and straightforward. Writing correct code is easier
   than writing buggy code.
 * No header files required. Top level declarations are entirely
   order-independent.
 * Compile-time code execution. Compile-time reflection.
 * Partial compile-time function evaluation with eliminates the need for
   a preprocessor or macros.
 * Tagged union enum type. No more accidentally reading the wrong union field.
 * Generics so that one can write efficient data structures that work for any
   data type.
 * Easy to parse language so that humans and machines have no trouble with the
   syntax.
 * The binaries produced by Zig have complete debugging information so you can,
   for example, use GDB to debug your software.
 * Debug mode optimizes for fast compilation time and crashing when undefined
   behavior *would* happen.
 * Release mode produces heavily optimized code. What other projects call
   "Link Time Optimization" Zig does automatically.
 * Mark functions as tests and automatically run them with `zig test`.
 * Currently supported architectures: `x86_64`, `i386`
 * Currently supported operating systems: linux, macosx
 * Friendly toward package maintainers. Reproducible build, bootstrapping
   process carefully documented. Issues filed by package maintainers are
   considered especially important.
 * Easy cross-compiling.

## Planned Features

 * In addition to creating executables, creating a C library is a primary use
   case. You can export an auto-generated .h file.
 * Eliminate the need for configure, make, cmake, etc.
 * Automatically provide test coverage.
 * Ability to declare dependencies as Git URLS with commit locking (can
   provide a tag or sha256).
 * Include documentation generator.
 * Compiler exposes itself as a library.
 * Support for all popular architectures and operating systems.

## Community

 * IRC: `#zig` on Freenode.
 * Reddit: [/r/zig](https://www.reddit.com/r/zig)
 * Email list: [ziglang@googlegroups.com](https://groups.google.com/forum/#!forum/ziglang)

## Building

### Dependencies

#### Build Dependencies

These compile tools must be available on your system and are used to build
the Zig compiler itself:

 * gcc >= 5.0.0 or clang >= 3.6.0
 * cmake >= 2.8.5

#### Runtime Dependencies

These libraries must be installed on your system, with the development files
available. The Zig compiler dynamically links against them.

 * LLVM == 3.9.x
 * libclang == 3.9.x

### Debug / Development Build

If you have gcc or clang installed, you can find out what `ZIG_LIBC_LIB_DIR`,
`ZIG_LIBC_STATIC_LIB_DIR`, and `ZIG_LIBC_INCLUDE_DIR` should be set to
(example below).

For MacOS, `ZIG_LIBC_LIB_DIR` and `ZIG_LIBC_STATIC_LIB_DIR` are unused.

```
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd) -DZIG_LIBC_LIB_DIR=$(dirname $(cc -print-file-name=crt1.o)) -DZIG_LIBC_INCLUDE_DIR=$(echo -n | cc -E -x c - -v 2>&1 | grep -B1 "End of search list." | head -n1 | cut -c 2-) -DZIG_LIBC_STATIC_LIB_DIR=$(dirname $(cc -print-file-name=crtbegin.o))
make
make install
./run_tests
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

### Troubleshooting

If you get one of these:

```
undefined reference to `_ZNK4llvm17SubtargetFeatures9getStringB5cxx11Ev'
undefined reference to `llvm::SubtargetFeatures::getString() const'
```

This is because of
[C++'s Dual ABI](https://gcc.gnu.org/onlinedocs/libstdc++/manual/using_dual_abi.html).
Most likely LLVM was compiled with one compiler while Zig was compiled with a
different one, for example GCC vs clang.

To fix this, you have 2 options:

 * Compile Zig with the same compiler that LLVM was compiled with.
 * Add `-DZIG_LLVM_OLD_CXX_ABI=yes` to the cmake configure line.
