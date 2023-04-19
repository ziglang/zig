#!/bin/sh

set -x
set -e

ZIGDIR="$(pwd)"
TARGET="$ARCH-macos-none"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.11.0-dev.2441+eb19f73af"
PREFIX="$HOME/$CACHE_BASENAME"
JOBS="-j3"

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

rm -rf build
mkdir build
cd build

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$(pwd)/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$(pwd)/zig-local-cache"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$TARGET;-mcpu=$MCPU" \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON

make $JOBS install

stage3/bin/zig build test docs \
  --zig-lib-dir "$(pwd)/../lib" \
  -Denable-macos-sdk \
  -Dstatic-llvm \
  -Dskip-non-native \
  --search-prefix "$PREFIX"

# Produce the experimental std lib documentation.
stage3/bin/zig test ../lib/std/std.zig -femit-docs -fno-emit-bin --zig-lib-dir ../lib

# Ensure that stage3 and stage4 are byte-for-byte identical.
stage3/bin/zig build \
  --prefix stage4 \
  -Denable-llvm \
  -Dno-lib \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dtarget=$TARGET \
  -Duse-zig-libcxx \
  -Dversion-string="$(stage3/bin/zig version)"

# Disabled due to https://github.com/ziglang/zig/issues/15197
## diff returns an error code if the files differ.
#echo "If the following command fails, it means nondeterminism has been"
#echo "introduced, making stage3 and stage4 no longer byte-for-byte identical."
#diff stage3/bin/zig stage4/bin/zig
