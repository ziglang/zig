#!/bin/sh


# Requires cmake ninja-build

set -x
set -e

ZIGDIR="$(pwd)"
TARGET="$ARCH-linux-musl"
MCPU="baseline"
CACHE_BASENAME="zig+llvm+lld+clang-$TARGET-0.10.0-dev.4560+828735ac0"
PREFIX="$HOME/$CACHE_BASENAME"
JOBS="-j2"

rm -rf $PREFIX
cd $HOME

wget -nv "https://ziglang.org/deps/$CACHE_BASENAME.tar.xz"
tar xf "$CACHE_BASENAME.tar.xz"

ZIG="$PREFIX/bin/zig" 

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"
export PATH=$DEPS_LOCAL/bin:$PATH

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

stage3-release/bin/zig build test docs \
  -fqemu \
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

# Explicit exit helps show last command duration.
exit