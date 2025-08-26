#!/bin/sh

set -x
set -e

# Script assumes the presence of the following:
# s3cmd

ZIGDIR="$PWD"
TARGET="$ARCH-macos-none"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.15.0-dev.233+7c85dc460"
PREFIX="$HOME/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

if [ ! -d "$PREFIX" ]; then
  cd $HOME
  curl -L -O "https://ziglang.org/deps/$CACHE_BASENAME.tar.xz"
  tar xf "$CACHE_BASENAME.tar.xz"
fi

cd $ZIGDIR

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git fetch --unshallow || true
git fetch --tags

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$PWD/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"

mkdir build-release
cd build-release

PATH="$HOME/local/bin:$PATH" cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3-release" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$TARGET;-mcpu=$MCPU" \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

$HOME/local/bin/ninja install

stage3-release/bin/zig build test docs \
  --zig-lib-dir "$PWD/../lib" \
  -Denable-macos-sdk \
  -Dstatic-llvm \
  -Dskip-non-native \
  --search-prefix "$PREFIX"

# Ensure that dependency overrides function correctly
wd=$PWD

cd ../test/dependency_override
./run-tests.sh ../../build-release/stage3-release/bin/zig
cd $wd

unset wd

# Ensure that stage3 and stage4 are byte-for-byte identical.
stage3-release/bin/zig build \
  --prefix stage4-release \
  -Denable-llvm \
  -Dno-lib \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dtarget=$TARGET \
  -Duse-zig-libcxx \
  -Dversion-string="$(stage3-release/bin/zig version)"

# diff returns an error code if the files differ.
echo "If the following command fails, it means nondeterminism has been"
echo "introduced, making stage3 and stage4 no longer byte-for-byte identical."
diff stage3-release/bin/zig stage4-release/bin/zig
