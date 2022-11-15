#!/bin/sh


# Requires cmake ninja-build

set -x
set -e

ZIGDIR="$(pwd)"
ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.10.0-dev.4560+828735ac0"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig" 

export PATH="$HOME/deps/wasmtime-v2.0.2-aarch64-linux:$PATH"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
git fetch --unshallow || true
git fetch --tags

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

mkdir build-release
cd build-release
cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-release" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

ninja install

# TODO: add -fqemu back to this line

stage3-release/bin/zig build test docs \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$(pwd)/../lib"

# Produce the experimental std lib documentation.
mkdir -p "stage3-release/doc/std"
stage3-release/bin/zig test ../lib/std/std.zig \
  -femit-docs=stage3-release/doc/std \
  -fno-emit-bin \
  --zig-lib-dir "$(pwd)/../lib"

# cp ../LICENSE $RELEASE_STAGING/
# cp ../zig-cache/langref.html $RELEASE_STAGING/doc/

# # Look for HTML errors.
# tidy --drop-empty-elements no -qe $RELEASE_STAGING/doc/langref.html
