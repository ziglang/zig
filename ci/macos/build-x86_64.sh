#!/bin/sh

set -x
set -e

echo "Running on Version:" $MACOS_VERSION

# Script assumes the presence of the following:
# s3cmd 

ZIGDIR="$(pwd)"
TARGET="$ARCH-macos-none"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.10.0-dev.4560+828735ac0"
PREFIX="$HOME/$CACHE_BASENAME"
JOBS="-j2"

rm -rf $PREFIX
cd $HOME

curl -L -O "https://ziglang.org/deps/$CACHE_BASENAME.tar.xz"
tar xf "$CACHE_BASENAME.tar.xz"

ZIG="$PREFIX/bin/zig"

cd $ZIGDIR

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
git fetch --unshallow || true
git fetch --tags

mkdir build
cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-release" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$TARGET;-mcpu=$MCPU" \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON

make $JOBS install

stage3-release/bin/zig build test docs \
  --zig-lib-dir "$(pwd)/../lib" \
  -Denable-macos-sdk \
  -Dstatic-llvm \
  -Dskip-non-native \
  --search-prefix "$PREFIX"

# Produce the experimental std lib documentation.
mkdir -p "stage3-release/doc/std"
stage3-release/bin/zig test "$(pwd)/../lib/std/std.zig" \
  --zig-lib-dir "$(pwd)/../lib" \
  -femit-docs="$(pwd)/stage3-release/doc/std" \
  -fno-emit-bin
