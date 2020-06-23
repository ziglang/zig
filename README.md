![ZIG](https://ziglang.org/zig-logo.svg)

A general-purpose programming language and toolchain for maintaining
**robust**, **optimal**, and **reusable** software.

## Resources

 * [Introduction](https://ziglang.org/#Introduction)
 * [Download & Documentation](https://ziglang.org/download)
 * [Community](https://github.com/ziglang/zig/wiki/Community)
 * [Contributing](https://github.com/ziglang/zig/blob/master/CONTRIBUTING.md)
 * [Frequently Asked Questions](https://github.com/ziglang/zig/wiki/FAQ)
 * [Community Projects](https://github.com/ziglang/zig/wiki/Community-Projects)

## Building from Source

[![Build Status](https://dev.azure.com/ziglang/zig/_apis/build/status/ziglang.zig?branchName=master)](https://dev.azure.com/ziglang/zig/_build/latest?definitionId=1&branchName=master)

Note that you can
[download a binary of master branch](https://ziglang.org/download/#release-master).

### Stage 1: Build Zig from C++ Source Code

#### Dependencies

##### POSIX

 * cmake >= 2.8.5
 * gcc >= 5.0.0 or clang >= 3.6.0
 * LLVM, Clang, LLD development libraries == 10.x, compiled with the same gcc or clang version above
   - Use the system package manager, or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#posix).

##### Windows

 * cmake >= 3.15.3
 * Microsoft Visual Studio. Supported versions:
   - 2015 (version 14)
   - 2017 (version 15.8)
   - 2019 (version 16)
 * LLVM, Clang, LLD development libraries == 10.x
   - Use the [pre-built binaries](https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows) or [build from source](https://github.com/ziglang/zig/wiki/How-to-build-LLVM,-libclang,-and-liblld-from-source#windows).

#### Instructions

##### POSIX

```
mkdir build
cd build
cmake ..
make install
```

Some special considerations for specific hosts:

###### Archlinux

The Clang package distributed via official Pacman sources isn't built with static libraries, therefore, it is not possible to statically link
  against individual Clang libs. Instead, one should link against `libclang-cpp.so`. More on this [here](https://bugs.archlinux.org/task/66283).
  Thus, when building on Archlinux, you need to pass `ZIG_PREFER_CLANG_CPP_DYLIB` flag set to true like so:
  
  ```
  cmake .. -DZIG_PREFER_CLANG_CPP_DYLIB=true
  ```

##### MacOS

```
brew install cmake llvm
brew outdated llvm || brew upgrade llvm
mkdir build
cd build
cmake .. -DCMAKE_PREFIX_PATH=$(brew --prefix llvm)
make install
```

You will now run into this issue:
[homebrew and llvm 10 packages in apt.llvm.org are broken with undefined reference to getPollyPluginInfo](https://github.com/ziglang/zig/issues/4799)

Please help upstream LLVM and Homebrew solve this issue, there is nothing Zig
can do about it. See that issue for a workaround you can do in the meantime.

##### Windows

See https://github.com/ziglang/zig/wiki/Building-Zig-on-Windows
