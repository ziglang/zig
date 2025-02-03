#!/bin/sh

set -x
set -e

ZIGDIR="$PWD"
PREFIX="$HOME/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

if [ ! -d "$PREFIX" ]; then
  cd $HOME
  curl -L -O "https://ziglang.org/deps/$CACHE_BASENAME.tar.xz"
  tar xf "$CACHE_BASENAME.tar.xz"
fi

cd $ZIGDIR

rm -rf build
mkdir build
cd build

export ZIG_GLOBAL_CACHE_DIR="$PWD/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"

PATH="$HOME/local/bin:$PATH" cmake .. \
  -DCMAKE_INSTALL_PREFIX="stage3" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_C_COMPILER="$ZIG;cc;-target;$TARGET;-mcpu=$MCPU" \
  -DCMAKE_CXX_COMPILER="$ZIG;c++;-target;$TARGET;-mcpu=$MCPU" \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -DZIG_VERSION="0.14.0-dev.2987+183bb8b08" \
  -GNinja

ninja install
