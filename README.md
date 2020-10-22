![ZIG](https://ziglang.org/zig-logo.svg)

A general-purpose programming language and toolchain for maintaining
**robust**, **optimal**, and **reusable** software.

## Resources

 * [Introduction](https://ziglang.org/#Introduction)
 * [Download & Documentation](https://ziglang.org/download)
 * [Chapter 0 - Getting Started | ZigLearn.org](https://ziglearn.org/)
 * [Community](https://github.com/ziglang/zig/wiki/Community)
 * [Contributing](https://github.com/ziglang/zig/blob/master/CONTRIBUTING.md)
 * [Code of Conduct](https://github.com/ziglang/zig/blob/master/CODE_OF_CONDUCT.md)
 * [Frequently Asked Questions](https://github.com/ziglang/zig/wiki/FAQ)
 * [Community Projects](https://github.com/ziglang/zig/wiki/Community-Projects)

## Building from Source

[![Build Status](https://dev.azure.com/ziglang/zig/_apis/build/status/ziglang.zig?branchName=master)](https://dev.azure.com/ziglang/zig/_build/latest?definitionId=1&branchName=master)

Note that you can
[download a binary of master branch](https://ziglang.org/download/#release-master) or 
[install Zig from a package manager](https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager).

### Stage 1: Build Zig from C++ Source Code

This step must be repeated when you make changes to any of the C++ source code.

#### Dependencies

##### POSIX

 * cmake >= 2.8.5
 * gcc >= 5.0.0 or clang >= 3.6.0
 * LLVM, Clang, LLD development libraries == 11.x, compiled with the same gcc or clang version above
   - Use the system package manager, or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#posix).

##### Windows

 * cmake >= 3.15.3
 * Microsoft Visual Studio. Supported versions:
   - 2017 (version 15.8)
   - 2019 (version 16)
 * LLVM, Clang, LLD development libraries == 11.x
   - Use the [pre-built binaries](https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows) or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#windows).

#### Instructions

##### POSIX

```
mkdir build
cd build
cmake ..
make install
```

Need help? [Troubleshooting Build Issues](https://github.com/ziglang/zig/wiki/Troubleshooting-Build-Issues)

##### MacOS

```
brew install cmake llvm
brew outdated llvm || brew upgrade llvm
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=$(brew --prefix llvm)
make install
```

##### Windows

See https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows

### Stage 2: Build Self-Hosted Zig from Zig Source Code

Now we use the stage1 binary:

```
zig build --prefix $(pwd)/stage2 -Denable-llvm
```

This produces `stage2/bin/zig` which can be used for testing and development.
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
stage2/bin/zig build
```

This produces `zig-cache/bin/zig`.

#### Release / Install Build

```
stage2/bin/zig build install -Drelease
```

## License

The ultimate goal of the Zig project is to serve users. As a first-order
effect, this means users of the compiler, helping programmers to write better
software. Even more important, however, are the end users.

Zig is intended to be used to help **end users** accomplish their goals. Zig
should be used to empower end users, never to exploit them financially or to
limit their freedom to interact with hardware or software in any way.

However, such problems are best solved with social norms, not with software
licenses. Any attempt to complicate the software license of Zig would risk
compromising the value Zig provides.

Therefore, Zig is available under the MIT (Expat) License, and comes with a
humble request: use it to make software better serve the needs of end users.

This project redistributes code from other projects, some of which have other
licenses besides MIT. Such licenses are generally similar to the MIT license
for practical purposes. See the subdirectories and files inside lib/ for more
details.
