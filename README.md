# zig lang

An experiment in writing a low-level programming language with the intent to
replace C. Zig intends to be a small language, yet powerful enough to write
optimal, readable, safe, and concise code to solve any computing problem.

Porting a C project to Zig should be a pleasant experience - every C feature
needs a corresponding Zig feature which solves the problem equivalently or
better.

Zig is not afraid to roll the major version number of the language if it
improves simplicity, fixes poor design decisions, or adds a new feature which
compromises backward compatibility.

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
 * Powerful constant expression evaluator. Generally, anything that *can* be
   figured out at compile time *is* figured out at compile time.
 * Tagged union enum type. No more accidentally reading the wrong union field.
 * Easy to parse language so that humans and machines have no trouble with the
   syntax.
 * The binaries produced by Zig have complete debugging information so you can,
   for example, use GDB to debug your software.
 * Release mode produces heavily optimized code. What other projects call
   "Link Time Optimization" Zig does automatically.
 * Supported architectures: `x86_64`
 * Supported operating systems: Linux

## Planned Features

 * In addition to creating executables, creating a C library is a primary use
   case. You can export an auto-generated .h file.
 * Generics so that one can write efficient data structures that work for any
   data type.
 * Eliminate the need for configure, make, cmake, etc.
 * Eliminate the preprocessor, but (most) everything you can accomplish with
   the preprocessor, you can accomplish directly in the language.
 * Ability to mark functions as test and automatically run them in test mode.
   Automatically provide test coverage.
 * Friendly toward package maintainers.
 * Ability to declare dependencies as Git URLS with commit locking (can
   provide a tag or sha1).
 * Include documentation generator.
 * Shebang line OK so language can be used for "scripting" as well.
 * Debug mode optimizes for fast compilation time and crashing when undefined
   behavior *would* happen.
 * Compiler exposes itself as a library.
 * Support for all popular architectures and operating systems.
 * Easy cross-compiling.

## Building

### Dependencies

 * LLVM 3.7.1
 * libclang 3.7.1

### Debug / Development Build

If you have gcc or clang installed, you can find out what `ZIG_LIBC_DIR` should
be set to (example below).

```
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd) -DZIG_LIBC_DIR=$(dirname $(dirname $(cc -print-file-name=crt1.o)))
make
make install
./run_tests
```

### Release / Install Build

Once installed, `ZIG_LIBC_DIR` can be overridden by the `--libc-path` parameter
to the zig binary.

```
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DZIG_LIBC_DIR=path/to/libc/dir
make
sudo make install
```

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

## Community

Zig is in its infancy. However one place you can gather to chat is the `#zig`
IRC channel on Freenode.
