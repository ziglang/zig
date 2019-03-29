![ZIG](https://ziglang.org/zig-logo.svg)

Zig is an open-source programming language designed for **robustness**,
**optimality**, and **maintainability**.

[Download & Documentation](https://ziglang.org/download/)

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
   always compiled against statically in source form. Zig binaries do not
   depend on libc unless explicitly linked.
 * Optional type instead of null pointers.
 * Safe unions, tagged unions, and C ABI compatible unions.
 * Generics so that one can write efficient data structures that work for any
   data type.
 * No header files required. Top level declarations are entirely
   order-independent.
 * Compile-time code execution. Compile-time reflection.
 * Partial compile-time function evaluation which eliminates the need for
   a preprocessor or macros.
 * The binaries produced by Zig have complete debugging information so you can,
   for example, use GDB, MSVC, or LLDB to debug your software.
 * Built-in unit tests with `zig test`.
 * Friendly toward package maintainers. Reproducible build, bootstrapping
   process carefully documented. Issues filed by package maintainers are
   considered especially important.
 * Cross-compiling is a primary use case.
 * In addition to creating executables, creating a C library is a primary use
   case. You can export an auto-generated .h file.

### Supported Targets

#### Tier 1 Support

 * Not only can Zig generate machine code for these targets, but the standard
   library cross-platform abstractions have implementations for these targets.
   Thus it is practical to write a pure Zig application with no dependency on
   libc.
 * The CI server automatically tests these targets on every commit to master
   branch, and updates ziglang.org/download with links to pre-built binaries.
 * These targets have debug info capabilities and therefore produce stack
   traces on failed assertions.
 * ([coming soon](https://github.com/ziglang/zig/issues/514)) libc is available
   for this target even when cross compiling.

#### Tier 2 Support

 * There may be some standard library implementations, but many abstractions
   will give an "Unsupported OS" compile error. One can link with libc or other
   libraries to fill in the gaps in the standard library.
 * These targets are known to work, but are not automatically tested, so there
   are occasional regressions.
 * Some tests may be disabled for these targets as we work toward Tier 1
   support.

#### Tier 3 Support

 * The standard library has little to no knowledge of the existence of this
   target.
 * Because Zig is based on LLVM, it has the capability to build for these
   targets, and LLVM has the target enabled by default.
 * These targets are not frequently tested; one will likely need to contribute
   to Zig in order to build for these targets.
 * The Zig compiler might need to be updated with a few things such as
   - what sizes are the C integer types
   - C ABI calling convention for this target
   - bootstrap code and default panic handler
 * `zig targets` is guaranteed to include this target.

#### Tier 4 Support

 * Support for these targets is entirely experimental.
 * LLVM may have the target as an experimental target, which means that you
   need to use Zig-provided binaries for the target to be available, or
   build LLVM from source with special configure flags. `zig targets` will
   display the target if it is available.
 * This target may be considered deprecated by an official party,
   [such as macosx/i386](https://support.apple.com/en-us/HT208436) in which
   case this target will remain forever stuck in Tier 4.
 * This target may only support `--emit asm` and cannot emit object files.

#### Support Table

|             | freestanding | linux  | macosx | windows | freebsd | netbsd | UEFI   | other  |
|-------------|--------------|--------|--------|---------|---------|------- | -------|--------|
|x86_64       | Tier 2       | Tier 1 | Tier 1 | Tier 1  | Tier 2  | Tier 2 | Tier 2 | Tier 3 |
|i386         | Tier 2       | Tier 2 | Tier 4 | Tier 2  | Tier 3  | Tier 3 | Tier 3 | Tier 3 |
|arm          | Tier 2       | Tier 3 | Tier 3 | Tier 3  | Tier 3  | Tier 3 | Tier 3 | Tier 3 |
|arm64        | Tier 2       | Tier 2 | Tier 3 | Tier 3  | Tier 3  | Tier 3 | Tier 3 | Tier 3 |
|bpf          | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|hexagon      | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|mips         | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|powerpc      | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|amdgcn       | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|sparc        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|s390x        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|lanai        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|wasm32       | Tier 3       | N/A    | N/A    | N/A     | N/A     | N/A    | N/A    | N/A    |
|wasm64       | Tier 3       | N/A    | N/A    | N/A     | N/A     | N/A    | N/A    | N/A    |
|avr          | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|riscv32      | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | Tier 4 | Tier 4 |
|riscv64      | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | Tier 4 | Tier 4 |
|xcore        | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|nvptx        | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|msp430       | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|r600         | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|arc          | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|tce          | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|le           | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|amdil        | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|hsail        | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|spir         | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|kalimba      | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|shave        | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |
|renderscript | Tier 4       | Tier 4 | N/A    | N/A     | Tier 4  | Tier 4 | N/A    | Tier 4 |

## Community

 * IRC: `#zig` on Freenode ([Channel Logs](https://irclog.whitequark.org/zig/)).
 * Reddit: [/r/zig](https://www.reddit.com/r/zig)
 * Email list: [~andrewrk/ziglang@lists.sr.ht](https://lists.sr.ht/%7Eandrewrk/ziglang)

## Building

[![Build Status](https://dev.azure.com/ziglang/zig/_apis/build/status/ziglang.zig?branchName=master)](https://dev.azure.com/ziglang/zig/_build/latest?definitionId=1&branchName=master)

Note that you can
[download a binary of master branch](https://ziglang.org/download/#release-master).

### Stage 1: Build Zig from C++ Source Code

#### Dependencies

##### POSIX

 * cmake >= 2.8.5
 * gcc >= 5.0.0 or clang >= 3.6.0
 * LLVM, Clang, LLD development libraries == 8.x, compiled with the same gcc or clang version above

##### Windows

 * cmake >= 2.8.5
 * Microsoft Visual Studio 2017 (version 15.8)
 * LLVM, Clang, LLD development libraries == 8.x, compiled with the same MSVC version above

#### Instructions

##### Build LLVM

Optionally build LLVM sources if current version isn't installed:
```
cd vendor/llvm && make -jN
```
Then link them statically to zig by adding to your zig cmake line:
`-DCMAKE_PREFIX_PATH=$(pwd)/../vendor/llvm/dist -DLLVM_LINK_STATIC=on`,
for example, POSIX would be:
```
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=$(pwd)/../vendor/llvm/dist -DLLVM_LINK_STATIC=on
make
make install
bin/zig build --build-file ../build.zig test
```

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
brew install cmake llvm@8
brew outdated llvm@8 || brew upgrade llvm@8
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=/usr/local/Cellar/llvm/8.0.0
make install
bin/zig build --build-file ../build.zig test
```

##### Windows

See https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows

### Stage 2: Build Self-Hosted Zig from Zig Source Code

*Note: Stage 2 compiler is not complete. Beta users of Zig should use the
Stage 1 compiler for now.*

Dependencies are the same as Stage 1, except now you can use stage 1 to compile
Zig code.

```
bin/zig build --build-file ../build.zig --prefix $(pwd)/stage2 install
```

This produces `./stage2/bin/zig` which can be used for testing and development.
Once it is feature complete, it will be used to build stage 3 - the final compiler
binary.

### Stage 3: Rebuild Self-Hosted Zig Using the Self-Hosted Compiler

*Note: Stage 2 compiler is not yet able to build Stage 3. Building Stage 3 is
not yet supported.*

Once the self-hosted compiler can build itself, this will be the actual
compiler binary that we will install to the system. Until then, users should
use stage 1.

#### Debug / Development Build

```
./stage2/bin/zig build --build-file ../build.zig --prefix $(pwd)/stage3 install
```

#### Release / Install Build

```
./stage2/bin/zig build --build-file ../build.zig install -Drelease-fast
```
