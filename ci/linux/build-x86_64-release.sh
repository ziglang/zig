#!/bin/sh

set -x
set -e

ZIGDIR="$(pwd)"
ARCH="$(uname -m)"
DEPS_LOCAL="$HOME/local"
OLD_ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"

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
echo "building stage3-release with zig version $($OLD_ZIG version)"

export CC="$OLD_ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$OLD_ZIG c++ -target $TARGET -mcpu=$MCPU"

mkdir build
cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$(pwd)/stage3" \
  -DCMAKE_PREFIX_PATH="$DEPS_LOCAL" \
  -DCMAKE_BUILD_TYPE=Release \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

make -j2 install

"stage3/bin/zig" build test \
  -fqemu \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$DEPS_LOCAL" \
  --zig-lib-dir "$(pwd)/../lib"

"stage3/bin/zig" build \
  --prefix stage4 \
  -Denable-llvm \
  -Denable-stage1 \
  -Dno-lib \
  -Drelease \
  -Dstrip \
  -Dtarget=x86_64-linux-musl \
  -Duse-zig-libcxx \
  -Dversion-string="$(stage3/bin/zig version)"

# diff returns an error code if the files differ.
echo "If the following command fails, it means nondeterminism has been"
echo "introduced, making stage3 and stage4 no longer byte-for-byte identical."
diff stage3/bin/zig stage4/bin/zig
