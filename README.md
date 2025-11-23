![ZIG](https://ziglang.org/img/zig-logo-dynamic.svg)

A general-purpose programming language and toolchain for maintaining
**robust**, **optimal**, and **reusable** software.

https://ziglang.org/

## Documentation

If you are looking at this README file in a source tree, please refer to the
**Release Notes**, **Language Reference**, or **Standard Library
Documentation** corresponding to the version of Zig that you are using by
following the appropriate link on the
[download page](https://ziglang.org/download).

Otherwise, you're looking at a release of Zig, so you can find the language
reference at `doc/langref.html`, and the standard library documentation by
running `zig std`, which will open a browser tab.

## Installation

 * [download a pre-built binary](https://ziglang.org/download/)
 * [install from a package manager](https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager)
 * [bootstrap zig for any target](https://github.com/ziglang/zig-bootstrap)

A Zig installation is composed of two things:

1. The Zig executable
2. The lib/ directory

At runtime, the executable searches up the file system for the lib/ directory,
relative to itself:

* lib/
* lib/zig/
* ../lib/
* ../lib/zig/
* (and so on)

In other words, you can **unpack a release of Zig anywhere**, and then begin
using it immediately. There is no need to install it globally, although this
mechanism supports that use case too (i.e. `/usr/bin/zig` and `/usr/lib/zig/`).

## Building from Source

Ensure you have the required dependencies:

 * CMake >= 3.15
 * System C/C++ Toolchain
 * LLVM, Clang, LLD development libraries, version 21.x, compiled with the
   same system C/C++ toolchain.
   - If the system package manager lacks these libraries, or has them misconfigured,
     see below for how to build them from source.

Then it is the standard CMake build process:

```
mkdir build
cd build
cmake ..
make install
```

Use `CMAKE_PREFIX_PATH` if needed to help CMake find LLVM.

This produces `stage3/bin/zig` which is the Zig compiler built by itself.

## Building from Source without LLVM

In this case, the only system dependency is a C compiler.

```
cc -o bootstrap bootstrap.c
./bootstrap
```

This produces a `zig2` executable in the current working directory. This is a
"stage2" build of the compiler,
[without LLVM extensions](https://github.com/ziglang/zig/issues/16270), and is
therefore lacking these features:
- Release mode optimizations
- [Some ELF linking features](https://github.com/ziglang/zig/issues/17749)
- [Some COFF/PE linking features](https://github.com/ziglang/zig/issues/17751)
- [Some WebAssembly linking features](https://github.com/ziglang/zig/issues/17750)
- [Ability to create static archives from object files](https://github.com/ziglang/zig/issues/9828)
- [Ability to compile assembly files](https://github.com/ziglang/zig/issues/21169)
- Ability to compile C, C++, Objective-C, and Objective-C++ files

Even when built this way, Zig provides an LLVM backend that produces bitcode
files, which may be optimized and compiled into object files via a system Clang
package. This can be used to produce system packages of Zig applications
without the Zig package dependency on LLVM.

## Building from Source Using Prebuilt Zig

Dependencies:

 * A recent prior build of Zig. The exact version required depends on how
   recently breaking changes occurred. If the language or std lib changed too
   much since this version, then this method of building from source will fail.
 * LLVM, Clang, and LLD libraries built using Zig.

The easiest way to obtain both of these artifacts is to use
[zig-bootstrap](https://github.com/ziglang/zig-bootstrap), which creates the
directory `out/zig-$target-$cpu` and `out/$target-$cpu`, to be used as
`$ZIG_PREFIX` and `$LLVM_PREFIX`, respectively, in the following command:

```
"$ZIG_PREFIX/zig" build \
  -p stage3 \
  --search-prefix "$LLVM_PREFIX" \
  --zig-lib-dir "lib" \
  -Dstatic-llvm
```

Where `$LLVM_PREFIX` is the path that contains, for example,
`include/llvm/Pass.h` and `lib/libLLVMCore.a`.

This produces `stage3/bin/zig`. See `zig build -h` to learn about the options
that can be passed such as `-Drelease`.

## Building from Source on Windows

### Option 1: Use the Windows Zig Compiler Dev Kit

This one has the benefit that LLVM, LLD, and Clang are built in Release mode,
while your Zig build has the option to be a Debug build. It also works
completely independently from MSVC so you don't need it to be installed.

Determine the URL by
[looking at the CI script](https://github.com/ziglang/zig/blob/master/ci/x86_64-windows-debug.ps1#L1-L4).
It will look something like this (replace `$VERSION` with the one you see by
following the above link):

```
https://ziglang.org/deps/zig+llvm+lld+clang-x86_64-windows-gnu-$VERSION.zip
```

This zip file contains:

 * An older Zig installation.
 * LLVM, LLD, and Clang libraries (.lib and .h files), version 16.0.1, built in Release mode.
 * zlib (.lib and .h files), v1.2.13, built in Release mode
 * zstd (.lib and .h files), v1.5.2, built in Release mode

#### Option 1a: CMake + [Ninja](https://ninja-build.org/)

Unzip the dev kit and then in cmd.exe in your Zig source checkout:

```bat
mkdir build
cd build
set DEVKIT=$DEVKIT
```

Replace `$DEVKIT` with the path to the folder that you unzipped after
downloading it from the link above. Make sure to use forward slashes (`/`) for
all path separators (otherwise CMake will try to interpret backslashes as
escapes and fail).

Then run:

```bat
cmake .. -GNinja -DCMAKE_PREFIX_PATH="%DEVKIT%" -DCMAKE_C_COMPILER="%DEVKIT%/bin/zig.exe;cc" -DCMAKE_CXX_COMPILER="%DEVKIT%/bin/zig.exe;c++" -DCMAKE_AR="%DEVKIT%/bin/zig.exe" -DZIG_AR_WORKAROUND=ON -DZIG_STATIC=ON -DZIG_USE_LLVM_CONFIG=OFF
```

 * Append `-DCMAKE_BUILD_TYPE=Release` for a Release build.
 * Append `-DZIG_NO_LIB=ON` to avoid having multiple copies of the lib/ folder.

Finally, run:

```bat
ninja install
```

You now have the `zig.exe` binary at `stage3\bin\zig.exe`.

#### Option 1b: zig build

Unzip the dev kit and then in cmd.exe in your Zig source checkout:

```bat
$DEVKIT\bin\zig.exe build -p stage3 --search-prefix $DEVKIT --zig-lib-dir lib -Dstatic-llvm -Duse-zig-libcxx -Dtarget=x86_64-windows-gnu
```

Replace `$DEVKIT` with the path to the folder that you unzipped after
downloading it from the link above.

Append `-Doptimize=ReleaseSafe` for a Release build.

**If you get an error building at this step**, it is most likely that the Zig
installation inside the dev kit is too old, and the dev kit needs to be
updated. In this case one more step is required:

 1. [Download the latest master branch zip file](https://ziglang.org/download/#release-master).
 2. Unzip, and try the above command again, replacing the path to zig.exe with
    the path to the zig.exe you just extracted, and also replace the lib\zig
    folder with the new contents.

You now have the `zig.exe` binary at `stage3\bin\zig.exe`.

### Option 2: Using CMake and Microsoft Visual Studio

This one has the benefit that changes to the language or build system won't
break your dev kit. This option can be used to upgrade a dev kit.

First, [build LLVM, LLD, and Clang from source using CMake and Microsoft Visual Studio](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#windows). Or, skip this step using a pre-built binary tarball, which unfortunately is not provided here.

Install [Build Tools for Visual Studio 2019](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2019). Be sure to select "Desktop development with C++" when prompted.
 * You must additionally check the optional component labeled **C++ ATL for v142 build tools**.

Install [CMake](http://cmake.org).

Use [git](https://git-scm.com/) to clone the zig repository to a path with no spaces, e.g. `C:\Users\Andy\zig`.

Using the start menu, run **x64 Native Tools Command Prompt for VS 2019** and execute these commands, replacing `C:\Users\Andy` with the correct value.

```bat
mkdir C:\Users\Andy\zig\build-release
cd C:\Users\Andy\zig\build-release
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_PREFIX_PATH=C:\Users\Andy\llvm+clang+lld-20.0.0-x86_64-windows-msvc-release-mt -DCMAKE_BUILD_TYPE=Release
msbuild -p:Configuration=Release INSTALL.vcxproj
```

You now have the `zig.exe` binary at `bin\zig.exe` and you can run the tests:

```bat
bin\zig.exe build test
```

This can take a long time. For tips & tricks on using the test suite, see [Contributing](https://github.com/ziglang/zig/blob/master/.github/CONTRIBUTING.md#editing-source-code).

Note: In case you get the error "llvm-config not found" (or similar), make sure that you have **no** trailing slash (`/` or `\`) at the end of the `-DCMAKE_PREFIX_PATH` value. 

## Building LLVM, LLD, and Clang from Source

### Windows

Install [CMake](https://cmake.org/), version 3.20.0 or newer.

[Download LLVM, Clang, and LLD sources](http://releases.llvm.org/download.html#21.0.0)
The downloads from llvm lead to the github release pages, where the source's
will be listed as : `llvm-21.X.X.src.tar.xz`, `clang-21.X.X.src.tar.xz`,
`lld-21.X.X.src.tar.xz`. Unzip each to their own directory. Ensure no
directories have spaces in them. For example:

 * `C:\Users\Andy\llvm-21.0.0.src`
 * `C:\Users\Andy\clang-21.0.0.src`
 * `C:\Users\Andy\lld-21.0.0.src`

Install [Build Tools for Visual Studio
2019](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2019).
Be sure to select "C++ build tools" when prompted.
 * You **must** additionally check the optional component labeled **C++ ATL for
   v142 build tools**. As this won't be supplied by a default installation of
   Visual Studio.
 * Full list of supported MSVC versions:
   - 2017 (version 15.8) (unverified)
   - 2019 (version 16.7)

Install [Python 3.9.4](https://www.python.org). Tick the box to add python to
your PATH environment variable.

#### LLVM

Using the start menu, run **x64 Native Tools Command Prompt for VS 2019** and execute these commands, replacing `C:\Users\Andy` with the correct value. Here is listed a brief explanation of each of the CMake parameters we pass when configuring the build

- `-Thost=x64` : Sets the windows toolset to use 64 bit mode.
- `-A x64` : Make the build target 64 bit .
- `-G "Visual Studio 16 2019"` : Specifies to generate a 2019 Visual Studio project, the best supported version.
- `-DCMAKE_INSTALL_PREFIX=""` : Path that llvm components will being installed into by the install project.
- `-DCMAKE_PREFIX_PATH=""` : Path that CMake will look into first when trying to locate dependencies, should be the same place as the install prefix. This will ensure that clang and lld will use your newly built llvm libraries.
- `-DLLVM_ENABLE_ZLIB=OFF` : Don't build llvm with ZLib support as it's not required and will disrupt the target dependencies for components linking against llvm. This only has to be passed when building llvm, as this option will be saved into the config headers.
- `-DCMAKE_BUILD_TYPE=Release` : Build llvm and components in release mode.
- `-DCMAKE_BUILD_TYPE=Debug` : Build llvm and components in debug mode.
- `-DLLVM_USE_CRT_RELEASE=MT` : Which C runtime should llvm use during release builds.
- `-DLLVM_USE_CRT_DEBUG=MTd` : Make llvm use the debug version of the runtime in debug builds.

##### Release Mode

```bat
mkdir C:\Users\Andy\llvm-21.0.0.src\build-release
cd C:\Users\Andy\llvm-21.0.0.src\build-release
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\Andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-release-mt -DCMAKE_PREFIX_PATH=C:\Users\Andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-release-mt -
DLLVM_ENABLE_ZLIB=OFF -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_USE_CRT_RELEASE=MT
msbuild /m -p:Configuration=Release INSTALL.vcxproj
```

##### Debug Mode

```bat
mkdir C:\Users\Andy\llvm-21.0.0.src\build-debug
cd C:\Users\Andy\llvm-21.0.0.src\build-debug
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -
DLLVM_ENABLE_ZLIB=OFF -DCMAKE_PREFIX_PATH=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -DCMAKE_BUILD_TYPE=Debug -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="AVR" -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_USE_CRT_DEBUG=MTd
msbuild /m INSTALL.vcxproj
```

#### LLD

Using the start menu, run **x64 Native Tools Command Prompt for VS 2019** and execute these commands, replacing `C:\Users\Andy` with the correct value.

##### Release Mode

```bat
mkdir C:\Users\Andy\lld-21.0.0.src\build-release
cd C:\Users\Andy\lld-21.0.0.src\build-release
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\Andy\llvm+clang+lld-14.0.6-x86_64-windows-msvc-release-mt -DCMAKE_PREFIX_PATH=C:\Users\Andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-release-mt -DCMAKE_BUILD_TYPE=Release -DLLVM_USE_CRT_RELEASE=MT
msbuild /m -p:Configuration=Release INSTALL.vcxproj
```

##### Debug Mode

```bat
mkdir C:\Users\Andy\lld-21.0.0.src\build-debug
cd C:\Users\Andy\lld-21.0.0.src\build-debug
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -DCMAKE_PREFIX_PATH=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -DCMAKE_BUILD_TYPE=Debug -DLLVM_USE_CRT_DEBUG=MTd
msbuild /m INSTALL.vcxproj
```

#### Clang

Using the start menu, run **x64 Native Tools Command Prompt for VS 2019** and execute these commands, replacing `C:\Users\Andy` with the correct value.

##### Release Mode

```bat
mkdir C:\Users\Andy\clang-21.0.0.src\build-release
cd C:\Users\Andy\clang-21.0.0.src\build-release
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\Andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-release-mt -DCMAKE_PREFIX_PATH=C:\Users\Andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-release-mt -DCMAKE_BUILD_TYPE=Release -DLLVM_USE_CRT_RELEASE=MT
msbuild /m -p:Configuration=Release INSTALL.vcxproj
```

##### Debug Mode

```bat
mkdir C:\Users\Andy\clang-21.0.0.src\build-debug
cd C:\Users\Andy\clang-21.0.0.src\build-debug
"c:\Program Files\CMake\bin\cmake.exe" .. -Thost=x64 -G "Visual Studio 16 2019" -A x64 -DCMAKE_INSTALL_PREFIX=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -DCMAKE_PREFIX_PATH=C:\Users\andy\llvm+clang+lld-21.0.0-x86_64-windows-msvc-debug -DCMAKE_BUILD_TYPE=Debug -DLLVM_USE_CRT_DEBUG=MTd
msbuild /m INSTALL.vcxproj
```

### POSIX Systems

This guide will get you both a Debug build of LLVM, and/or a Release build of LLVM.
It intentionally does not require privileged access, using a prefix inside your home
directory instead of a global installation.

#### Release

This is the generally recommended approach.

```
cd ~/Downloads
git clone --depth 1 --branch release/21.x https://github.com/llvm/llvm-project llvm-project-21
cd llvm-project-21
git checkout release/21.x

mkdir build-release
cd build-release
cmake ../llvm \
  -DCMAKE_INSTALL_PREFIX=$HOME/local/llvm21-assert \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="lld;clang" \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -G Ninja
ninja install
```

#### Debug

This is occasionally needed when debugging Zig's LLVM backend. Here we build
the three projects separately so that LLVM can be in Debug mode while the
others are in Release mode.

```
cd ~/Downloads
git clone --depth 1 --branch release/21.x https://github.com/llvm/llvm-project llvm-project-21
cd llvm-project-21
git checkout release/21.x

# LLVM
mkdir llvm/build-debug
cd llvm/build-debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$HOME/local/llvm21-debug \
  -DCMAKE_PREFIX_PATH=$HOME/local/llvm21-debug \
  -DCMAKE_BUILD_TYPE=Debug \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -G Ninja
ninja install
cd ../..

# LLD
mkdir lld/build-debug
cd lld/build-debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$HOME/local/llvm21-debug \
  -DCMAKE_PREFIX_PATH=$HOME/local/llvm21-debug \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_CXX_STANDARD=17 \
  -G Ninja
ninja install
cd ../..

# Clang
mkdir clang/build-debug
cd clang/build-debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$HOME/local/llvm21-debug \
  -DCMAKE_PREFIX_PATH=$HOME/local/llvm21-debug \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_INCLUDE_TESTS=OFF \
  -G Ninja
ninja install
cd ../..
```

Then add to your Zig CMake line that you got from the README.md:
`-DCMAKE_PREFIX_PATH=$HOME/local/llvm21-debug` or
`-DCMAKE_PREFIX_PATH=$HOME/local/llvm21-assert` depending on whether you want
Debug or Release LLVM.


## Contributing

[Donate monthly](https://ziglang.org/zsf/).

[Join a community](https://ziglang.org/community/).

Zig is Free and Open Source Software. We welcome bug reports and patches from
everyone. However, keep in mind that Zig governance is BDFN (Benevolent
Dictator For Now) which means that Andrew Kelley has final say on the design
and implementation of everything.

### Make Software With Zig

One of the best ways you can contribute to Zig is to start using it for an
open-source personal project.

This leads to discovering bugs and helps flesh out use cases, which lead to
further design iterations of Zig. Importantly, each issue found this way comes
with real world motivations, making it straightforward to explain the reasoning
behind proposals and feature requests.

Ideally, such a project will help you to learn new skills and add something
to your personal portfolio at the same time.

### Talk About Zig

Another way to contribute is to write about Zig, speak about Zig at a
conference, or do either of those things for your project which uses Zig.

Programming languages live and die based on the pulse of their ecosystems. The
more people involved, the more we can build great things upon each other's
abstractions.

### Strict No LLM / No AI Policy

No LLMs for issues.

No LLMs for patches / pull requests.

No LLMs for comments on the bug tracker, including translation.

English is encouraged, but not required. You are welcome to post in your native
language and rely on others to have their own translation tools of choice to
interpret your words.

### Find a Contributor Friendly Issue

The issue label
[Contributor Friendly](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3A%22contributor+friendly%22)
exists to help you find issues that are **limited in scope and/or
knowledge of Zig internals.**

Please note that issues labeled
[Proposal](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aproposal)
but do not also have the
[Accepted](https://github.com/ziglang/zig/issues?q=is%3Aissue+is%3Aopen+label%3Aaccepted)
label are still under consideration, and efforts to implement such a proposal
have a high risk of being wasted. If you are interested in a proposal which is
still under consideration, please express your interest in the issue tracker,
providing extra insights and considerations that others have not yet expressed.
The most highly regarded argument in such a discussion is a real world use case.

Language proposals are not accepted. Please do not open an issue proposing to
change the Zig language or syntax.

### Editing Source Code

For a smooth workflow, when building from source, it is recommended to use
CMake with the following settings:

 * `-DCMAKE_BUILD_TYPE=Release` - to recompile zig faster.
 * `-GNinja` - Ninja is faster and simpler to use than Make.
 * `-DZIG_NO_LIB=ON` - Prevents the build system from copying the lib/
   directory to the installation prefix, causing zig use lib/ directly from the
   source tree instead. Effectively, this makes it so that changes to lib/ do
   not require re-running the install command to become active.

After configuration, there are two scenarios:

 1. Pulling upstream changes and rebuilding.
    - In this case use `git pull` and then `ninja install`. Expected wait:
      about 10 minutes.
 2. Building from source after making local changes.
    - In this case use `stage3/bin/zig build -p stage4 -Denable-llvm -Dno-lib`.
      Expected wait: about 20 seconds.

This leaves you with two builds of Zig:

 * `stage3/bin/zig` - an optimized master branch build. Useful for
   miscellaneous activities such as `zig fmt`, as well as for building the
   compiler itself after changing the source code.
 * `stage4/bin/zig` - a debug build that includes your local changes; useful
   for testing and eliminating bugs before submitting a patch.

To reduce time spent waiting for the compiler to build, try these techniques:

 * Omit `-Denable-llvm` if you don't need the LLVM backend.
 * Use `-Ddev=foo` to build with a reduced feature set for development of
   specific features. See `zig build -h` for a list of options.
 * Use `--watch -fincremental` to enable incremental compilation. This offers
   **near instant rebuilds**.

### Testing

```
stage4/bin/zig build test
```

This command runs the whole test suite, which does a lot of extra testing that
you likely won't always need, and can take upwards of 1 hour. This is what the
CI server runs when you make a pull request.

To save time, you can add the `--help` option to the `zig build` command and
see what options are available. One of the most helpful ones is
`-Dskip-release`. Adding this option to the command above, along with
`-Dskip-non-native`, will take the time down from around 2 hours to about 30
minutes, and this is a good enough amount of testing before making a pull
request.

Another example is choosing a different set of things to test. For example,
`test-std` instead of `test` will only run the standard library tests, and
not the other ones. Combining this suggestion with the previous one, you could
do this:

```
stage4/bin/zig build test-std -Dskip-release
```

This will run only the standard library tests in debug mode for all targets.
It will cross-compile the tests for non-native targets but not run them.

When making changes to the compiler source code, the most helpful test step to
run is `test-behavior`. When editing documentation it is `docs`. You can find
this information and more in the `zig build --help` menu.

#### Directly Testing the Standard Library with `zig test`

This command will run the standard library tests with only the native target
configuration and is estimated to complete in 3 minutes:

```
zig build test-std -Dno-matrix
```

However, one may also use `zig test` directly. From inside the `ziglang/zig` repo root:

```
zig test lib/std/std.zig --zig-lib-dir lib
```

You can add `--test-filter "some test name"` to run a specific test or a subset of tests.
(Running exactly 1 test is not reliably possible, because the test filter does not
exclude anonymous test blocks, but that shouldn't interfere with whatever
you're trying to test in practice.)

Note that `--test-filter` filters on fully qualified names, so e.g. it's possible to run only the `std.json` tests with:

```
zig test lib/std/std.zig --zig-lib-dir lib --test-filter "json."
```

If you used `-Dno-lib` and you are in a `build/` subdirectory, you can omit the
`--zig-lib-dir` argument:

```
stage3/bin/zig test ../lib/std/std.zig
```

#### Testing Non-Native Architectures with QEMU

The Linux CI server additionally has qemu installed and sets `-fqemu`.
This provides test coverage for, e.g. aarch64 even on x86_64 machines. It's
recommended for Linux users to install qemu and enable this testing option
when editing the standard library or anything related to a non-native
architecture.

QEMU packages provided by some system package managers (such as Debian) may be
a few releases old, or may be missing newer targets such as aarch64 and RISC-V.
[ziglang/qemu-static](https://github.com/ziglang/qemu-static) offers static
binaries of the latest QEMU version.

##### Testing Non-Native glibc Targets

Testing foreign architectures with dynamically linked glibc is one step trickier.
This requires enabling `--glibc-runtimes /path/to/glibc/multi/install/glibcs`.
This path is obtained by building glibc for multiple architectures. This
process for me took an entire day to complete and takes up 65 GiB on my hard
drive. The CI server does not provide this test coverage.

[Instructions for producing this path](https://codeberg.org/ziglang/infra/src/branch/master/building-libcs.md#linux-glibc) (just the part with `build-many-glibcs.py`).

It is understood that most contributors will not have these tests enabled.

#### Testing Windows from a Linux Machine with Wine

When developing on Linux, another option is available to you: `-fwine`.
This will enable running behavior tests and std lib tests with Wine. It's
recommended for Linux users to install Wine and enable this testing option
when editing the standard library or anything Windows-related.

#### Testing WebAssembly using wasmtime

If you have [wasmtime](https://wasmtime.dev/) installed, take advantage of the
`-fwasmtime` flag which will enable running WASI behavior tests and std
lib tests. It's recommended for all users to install wasmtime and enable this
testing option when editing the standard library and especially anything
WebAssembly-related.

### Improving Translate-C

`translate-c` is a feature provided by Zig that converts C source code into
Zig source code. It powers the `zig translate-c` command as well as
[@cImport](https://ziglang.org/documentation/master/#cImport), allowing Zig
code to not only take advantage of function prototypes defined in .h files,
but also `static inline` functions written in C, and even some macros.

This feature used to work by using libclang API to parse and semantically
analyze C/C++ files, and then based on the provided AST and type information,
generating Zig AST, and finally using the mechanisms of `zig fmt` to render the
Zig AST to a file.

However, C translation is in a transitional period right now. It used to be
based on Clang, but is now based on Aro:

[Pull Request: update aro and translate-c to latest; delete clang translate-c](https://github.com/ziglang/zig/pull/24497)

Test coverage as well as bug reports have been moved to this repository:

[ziglang/translate-c](https://github.com/ziglang/translate-c/)

In the future, [@cImport will move to the build system](https://github.com/ziglang/zig/issues/20630),
but for now, the translate-c logic is copy-pasted from that project into
[ziglang/zig](https://github.com/ziglang/zig/), powering both `zig translate-c`
and `@cImport`.

Please see the readme of the translate-c project for how to contribute. Once an
issue is resolved (and test coverage added) there, the changes can be
immediately backported to the zig compiler.

Once we fix the problems people are facing from this transition from Clang to
Aro, we can move on to enhancing the translate-c package such that `@cImport`
becomes redundant and can therefore be eliminated from the language.

### Autodoc

Autodoc is an interactive, searchable, single-page web application for browsing
Zig codebases.

An autodoc deployment looks like this:

```
index.html
main.js
main.wasm
sources.tar
```

* `main.js` and `index.html` are static files which live in a Zig installation
  at `lib/docs/`.
* `main.wasm` is compiled from the Zig files inside `lib/docs/wasm/`.
* `sources.tar` is all the zig source files of the project.

These artifacts are produced by the compiler when `-femit-docs` is passed.

#### Making Changes

The command `zig std` spawns an HTTP server that provides all the assets
mentioned above specifically for the standard library.

The server creates the requested files on the fly, including rebuilding
`main.wasm` if any of its source files changed, and constructing `sources.tar`,
meaning that any source changes to the documented files, or to the autodoc
system itself are immediately reflected when viewing docs.

This means you can test changes to Zig standard library documentation, as well
as autodocs functionality, by pressing refresh in the browser.

Prefixing the URL with `/debug` results in a debug build of `main.wasm`.

#### Debugging the Zig Code

While Firefox and Safari support are obviously required, I recommend Chromium
for development for one reason in particular:

[C/C++ DevTools Support (DWARF)](https://chromewebstore.google.com/detail/cc++-devtools-support-dwa/pdcpmagijalfljmkmjngeonclgbbannb)

This makes debugging Zig WebAssembly code a breeze.

#### The Sources Tarball

The system expects the top level of `sources.tar` to be the set of modules
documented. So for the Zig standard library you would do this:
`tar cf std.tar std/`. Don't compress it; the idea is to rely on HTTP
compression.

Any files that are not `.zig` source files will be ignored by `main.wasm`,
however, those files will take up wasted space in the tar file. For the
standard library, use the set of files that zig installs to when running `zig
build`, which is the same as the set of files that are provided on
ziglang.org/download.

If the system doesn't find a file named "foo/root.zig" or "foo/foo.zig", it
will use the first file in the tar as the module root.

You don't typically need to create `sources.tar` yourself, since it is lazily
provided by the `zig std` HTTP server as well as produced by `-femit-docs`.


## Testing Zig Code With LLDB

[@jacobly0](https://github.com/jacobly0) maintains a fork of LLDB with Zig support: https://github.com/jacobly0/llvm-project/tree/lldb-zig

This fork only contains changes for debugging programs compiled by Zig's self-hosted backends, i.e. `zig build-exe -fno-llvm ...`.

### Building

To build the LLDB fork, make sure you have [prerequisites](https://lldb.llvm.org/resources/build.html#preliminaries) installed, and then do something like:

```console
$ cmake llvm -G Ninja -B build -DLLVM_ENABLE_PROJECTS="clang;lldb" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS=ON -DLLDB_ENABLE_LIBEDIT=ON -DLLDB_ENABLE_PYTHON=ON
$ cmake --build build --target lldb --target lldb-server
```

(You may need to manually [configure dependencies](https://lldb.llvm.org/resources/build.html#optional-dependencies) if CMake can't find them.)

Once built, you can run `./build/bin/lldb` and so on.

### Pretty Printers

If you will be debugging the Zig compiler itself, or if you will be debugging any project compiled with Zig's LLVM backend (not recommended with the LLDB fork, prefer vanilla LLDB with a version that matches the version of LLVM that Zig is using), you can get a better debugging experience by using [`lldb_pretty_printers.py`](https://github.com/ziglang/zig/blob/master/tools/lldb_pretty_printers.py).

Put this line in `~/.lldbinit`:

```
command script import /path/to/zig/tools/lldb_pretty_printers.py
```

If you will be using Zig's LLVM backend (again, not recommended with the LLDB fork), you will also want these lines:

```
type category enable zig.lang
type category enable zig.std
```
If you will be debugging a Zig compiler built using Zig's LLVM backend (again, not recommended with the LLDB fork), you will also want this line:
```
type category enable zig.stage2
```

