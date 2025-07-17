#!/bin/sh

# Requires cmake ninja-build

set -x
set -e

ARCH="$(uname -m)"
TARGET="$ARCH-linux-musl"
MCPU="spacemit_x60"
CACHE_BASENAME="zig+llvm+lld+clang-riscv64-linux-musl-0.15.0-dev.929+31e46be74"
PREFIX="$HOME/deps/$CACHE_BASENAME"
ZIG="$PREFIX/bin/zig"

export PATH="$HOME/local/bin:$PATH"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git fetch --unshallow || true
git fetch --tags

# Override the cache directories because they won't actually help other CI runs
# which will be testing alternate versions of zig, and ultimately would just
# fill up space on the hard drive for no reason.
export ZIG_GLOBAL_CACHE_DIR="$PWD/zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/zig-local-cache"

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

# No -fqemu and -fwasmtime here as they're covered by the x86_64-linux scripts.
stage3-debug/bin/zig build test-cases test-modules test-unit test-standalone test-c-abi test-link test-stack-traces test-asm-link test-llvm-ir \
  --maxrss 68719476736 \
  -Dstatic-llvm \
  -Dskip-non-native \
  -Dskip-translate-c \
  -Dskip-run-translated-c \
  -Dtarget=native-native-musl \
  --search-prefix "$PREFIX" \
  --zig-lib-dir "$PWD/../lib"
