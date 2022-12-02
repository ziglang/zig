#!/bin/sh

# Requires cmake ninja-build

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.11.0-dev.448+e6e459e9e"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

export PATH="$HOME/deps/wasmtime-v2.0.2-$ARCH-linux:$HOME/deps/qemu-linux-x86_64-6.1.0.1/bin:$PATH"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
git fetch --unshallow || true
git fetch --tags

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

rm -rf build-debug
mkdir build-debug
cd build-debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-debug" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

ninja install

echo "Looking for non-conforming code formatting..."
stage3-debug/bin/zig fmt --check .. \
  --exclude ../test/cases/ \
  --exclude ../build-debug

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3-debug/bin/zig build -Dtarget=arm-linux-musleabihf

stage3-debug/bin/zig build test docs \
  -fqemu \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$(pwd)/../lib"

# Look for HTML errors.
tidy --drop-empty-elements no -qe ../zig-cache/langref.html

# Produce the experimental std lib documentation.
stage3-debug/bin/zig test ../lib/std/std.zig \
  -femit-docs \
  -fno-emit-bin \
  --zig-lib-dir "$(pwd)/../lib"
