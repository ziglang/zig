#!/bin/sh

set -x
set -e

ZIGDIR="$(pwd)"
ARCH="$(uname -m)"
DEPS_LOCAL="$HOME/local"
OLD_ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"

mkdir -p "$DEPS_LOCAL"
cd "$DEPS_LOCAL"

OLD_ZIG_VERSION="0.11.0-dev.256+271cc52a1"
wget https://ziglang.org/deps/zig+llvm+lld+clang-x86_64-linux-musl-$OLD_ZIG_VERSION.tar.xz
tar x --strip-components=1 -f zig+llvm+lld+clang-x86_64-linux-musl-$OLD_ZIG_VERSION.tar.xz

wget https://ziglang.org/deps/qemu-linux-x86_64-6.1.0.1.tar.xz
tar x --strip-components=1 -f qemu-linux-x86_64-6.1.0.1.tar.xz

wget https://github.com/bytecodealliance/wasmtime/releases/download/v2.0.2/wasmtime-v2.0.2-x86_64-linux.tar.xz
tar x --strip-components=1 -f wasmtime-v2.0.2-x86_64-linux.tar.xz
rm -f LICENSE README.md
mv wasmtime bin/

export PATH=$DEPS_LOCAL/bin:$PATH

cd "$ZIGDIR"
echo "building stage3-debug with zig version $($OLD_ZIG version)"

"$OLD_ZIG" build \
  --prefix stage3
  --search-prefix "$DEPS_LOCAL" \
  --zig-lib-dir lib \
  -Denable-stage1 \
  -Dstatic-llvm \
  -Drelease \
  -Duse-zig-libcxx \
  -Dtarget="$TARGET"

echo "Looking for non-conforming code formatting..."
stage3/bin/zig fmt --check . \
  --exclude test/cases/ \
  --exclude build

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3/bin/zig build -Dtarget=arm-linux-musleabihf

stage3/bin/zig build test docs \
  -fqemu \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$DEPS_LOCAL" \
  --zig-lib-dir lib
