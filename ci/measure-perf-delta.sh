#!/bin/sh

set -x
set -e

if [ -z "$GITHUB_BASE_REF" ]; then
  exit 0
fi

ZIG="$1"
TARGET="$2"
MPCU="$3"
PREFIX="$4"

git checkout "$GITHUB_BASE_REF"

rm -rf ../build-base
mkdir ../build-base
cd ../build-base

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

cmake .. \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -DZIG_NO_LIB=ON \
  -GNinja

unset CC
unset CXX

ninja install

cd ..

poop \
  "build-base/stage3/bin/zig build-exe test/standalone/hello_world/hello.zig" \
  "build-new/stage3/bin/zig build-exe test/standalone/hello_world/hello.zig" \
  > build-new/perf.txt
