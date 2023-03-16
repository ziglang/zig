#!/bin/sh

# Requires cmake ninja-build

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.11.0-dev.971+19056cb68"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

export PATH="$HOME/deps/wasmtime-v2.0.2-$ARCH-linux:$PATH"

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

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$(pwd)/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$(pwd)/zig-local-cache"

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

# TODO: add -fqemu back to this line

stage3-debug/bin/zig build test docs \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$(pwd)/../lib"

# Look for HTML errors.
tidy --drop-empty-elements no -qe "stage3-debug/doc/langref.html"

# Produce the experimental std lib documentation.
stage3-debug/bin/zig test ../lib/std/std.zig -femit-docs -fno-emit-bin --zig-lib-dir ../lib

# Ensure that updating the wasm binary from this commit will result in a viable build.
stage3-debug/bin/zig build update-zig1

rm -rf ../build-new
mkdir ../build-new
cd ../build-new

export ZIG_GLOBAL_CACHE_DIR="$(pwd)/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$(pwd)/zig-local-cache"
export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

unset CC
unset CXX

ninja install

stage3/bin/zig test ../test/behavior.zig -I../test
stage3/bin/zig build -p stage4 \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$(pwd)/../lib"
stage4/bin/zig test ../test/behavior.zig -I../test
