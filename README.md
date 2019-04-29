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
|wasm32       | Tier 2       | N/A    | N/A    | N/A     | N/A     | N/A    | N/A    | Tier 2 |
|bpf          | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|hexagon      | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|mips         | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|powerpc32    | Tier 3       | Tier 3 | Tier 4 | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|powerpc64    | Tier 3       | Tier 3 | Tier 4 | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|amdgcn       | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|sparc        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|s390x        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|lanai        | Tier 3       | Tier 3 | N/A    | N/A     | Tier 3  | Tier 3 | N/A    | Tier 3 |
|wasm64       | Tier 4       | N/A    | N/A    | N/A     | N/A     | N/A    | N/A    | N/A    |
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

## Building from Source

[![Build Status](https://dev.azure.com/ziglang/zig/_apis/build/status/ziglang.zig?branchName=master)](https://dev.azure.com/ziglang/zig/_build/latest?definitionId=1&branchName=master)

Note that you can
[download a binary of master branch](https://ziglang.org/download/#release-master).

### Stage 1: Build Zig from C++ Source Code

#### Dependencies

##### POSIX

 * cmake >= 2.8.5
 * gcc >= 5.0.0 or clang >= 3.6.0
 * LLVM, Clang, LLD development libraries == 8.x, compiled with the same gcc or clang version above
   - Use the system package manager, or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#posix).

##### Windows

 * cmake >= 2.8.5
 * Microsoft Visual Studio 2017 (version 15.8)
 * LLVM, Clang, LLD development libraries == 8.x, compiled with the same MSVC version above
   - Use the [pre-built binaries](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#pre-built-binaries) or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#windows).

#### Instructions

##### POSIX

```
mkdir build
cd build
cmake ..
make install
```

##### MacOS

```
brew install cmake llvm@8
brew outdated llvm@8 || brew upgrade llvm@8
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=/usr/local/Cellar/llvm/8.0.0
make install
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

## Contributing

### Start a Project Using Zig

One of the best ways you can contribute to Zig is to start using it for a
personal project. Here are some great examples:

 * [Oxid](https://github.com/dbandstra/oxid) - arcade style game
 * [TM35-Metronome](https://github.com/TM35-Metronome) - tools for modifying and randomizing Pokémon games
 * [trOS](https://github.com/sjdh02/trOS) - tiny aarch64 baremetal OS thingy

Without fail, these projects lead to discovering bugs and helping flesh out use
cases, which lead to further design iterations of Zig. Importantly, each issue
found this way comes with a real world motivations, so it is easy to explain
your reasoning behind proposals and feature requests.

Ideally, such a project will help you to learn new skills and add something
to your personal portfolio at the same time.

### Spread the Word

Another way to contribute is to write about Zig, or speak about Zig at a
conference, or do either of those things for your project which uses Zig.
Here are some examples:

 * [Iterative Replacement of C with Zig](http://tiehuis.github.io/blog/zig1.html)
 * [The Right Tool for the Right Job: Redis Modules & Zig](https://www.youtube.com/watch?v=eCHM8-_poZY)

Zig is a brand new language, with no advertising budget. Word of mouth is the
only way people find out about the project, and the more people hear about it,
the more people will use it, and the better chance we have to take over the
world.

### Finding Contributor Friendly Issues

Please note that issues labeled
[Proposal](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aproposal)
but do not also have the
[Accepted](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aaccepted)
label are still under consideration, and efforts to implement such a proposal
have a high risk of being wasted. If you are interested in a proposal which is
still under consideration, please express your interest in the issue tracker,
providing extra insights and considerations that others have not yet expressed.
The most highly regarded argument in such a discussion is a real world use case.

The issue label
[Contributor Friendly](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3A%22contributor+friendly%22)
exists to help contributors find issues that are "limited in scope and/or
knowledge of Zig internals."

### Editing Source Code

First, build the Stage 1 compiler as described in [the Building section](#building).

When making changes to the standard library, be sure to edit the files in the
`std` directory and not the installed copy in the build directory. If you add a
new file to the standard library, you must also add the file path in
CMakeLists.txt.

To test changes, do the following from the build directory:

1. Run `make install` (on POSIX) or
   `msbuild -p:Configuration=Release INSTALL.vcxproj` (on Windows).
2. `bin/zig build --build-file ../build.zig test` (on POSIX) or
   `bin\zig.exe build --build-file ..\build.zig test` (on Windows).

That runs the whole test suite, which does a lot of extra testing that you
likely won't always need, and can take upwards of 2 hours. This is what the
CI server runs when you make a pull request.

To save time, you can add the `--help` option to the `zig build` command and
see what options are available. One of the most helpful ones is
`-Dskip-release`. Adding this option to the command in step 2 above will take
the time down from around 2 hours to about 6 minutes, and this is a good
enough amount of testing before making a pull request.

Another example is choosing a different set of things to test. For example,
`test-std` instead of `test` will only run the standard library tests, and
not the other ones. Combining this suggestion with the previous one, you could
do this:

`bin/zig build --build-file ../build.zig test-std -Dskip-release` (on POSIX) or
`bin\zig.exe build --build-file ..\build.zig test-std -Dskip-release` (on Windows).

This will run only the standard library tests, in debug mode only, for all
targets (it will cross-compile the tests for non-native targets but not run
them).

When making changes to the compiler source code, the most helpful test step to
run is `test-behavior`. When editing documentation it is `docs`. You can find
this information and more in the `--help` menu.
