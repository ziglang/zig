#!/bin/sh

# Requires cmake ninja-build

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.15.0-dev.233+7c85dc460"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

export PATH="$HOME/deps/wasmtime-v29.0.0-$ARCH-linux:$HOME/deps/qemu-linux-x86_64-9.2.0-rc1/bin:$HOME/local/bin:$PATH"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git fetch --unshallow || true
git fetch --tags

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$PWD/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"

# Test building from source without LLVM.
cc -o bootstrap bootstrap.c
./bootstrap
./zig2 build -Dno-lib
./zig-out/bin/zig test test/behavior.zig

mkdir build-debug
cd build-debug

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-debug" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

ninja install

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3-debug/bin/zig build \
  -Dtarget=arm-linux-musleabihf \
  -Dno-lib

stage3-debug/bin/zig build test docs \
  --maxrss 21000000000 \
  -Dlldb=$HOME/deps/lldb-zig/Debug-e0a42bb34/bin/lldb \
  -fqemu \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$PWD/../lib" \
  -Denable-superhtml

# Ensure that stage3 used as cc can build zig2.
mkdir ../build-zig2
cd ../build-zig2

export CC="$PWD/../build-debug/stage3-debug/bin/zig cc -target $TARGET -mcpu=$MCPU"
export CXX="$PWD/../build-debug/stage3-debug/bin/zig c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

unset CC
unset CXX

ninja zig2

# Ensure that updating the wasm binary from this commit will result in a viable build.
../build-debug/stage3-debug/bin/zig build update-zig1

mkdir ../build-new
cd ../build-new

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

unset CC
unset CXX

ninja install

stage3/bin/zig test ../test/behavior.zig
stage3/bin/zig build -p stage4 \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  -Dno-lib \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$PWD/../lib"
stage4/bin/zig test ../test/behavior.zig
