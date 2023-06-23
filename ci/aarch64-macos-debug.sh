#!/bin/sh

set -x
set -e

# Script assumes the presence of the following:
# s3cmd

ZIGDIR="$(pwd)"
TARGET="$ARCH-macos-none"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.11.0-dev.2441+eb19f73af"
PREFIX="$HOME/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

cd $ZIGDIR

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
git fetch --unshallow || true
git fetch --tags

mkdir build
cd build

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$(pwd)/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$(pwd)/zig-local-cache"

PATH="$HOME/local/bin:$PATH" cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-debug" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$TARGET;-mcpu=$MCPU" \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

$HOME/local/bin/ninja install

stage3-debug/bin/zig build test docs \
  --zig-lib-dir "$(pwd)/../lib" \
  -Denable-macos-sdk \
  -Dstatic-llvm \
  -Dskip-non-native \
  --search-prefix "$PREFIX"

# Produce the experimental std lib documentation.
stage3-debug/bin/zig test ../lib/std/std.zig -femit-docs -fno-emit-bin --zig-lib-dir ../lib
