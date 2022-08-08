#!/bin/sh

. ./ci/zinc/linux_base.sh

OLD_ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9

echo "building debug zig with zig version $($OLD_ZIG version)"

export CC="$OLD_ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$OLD_ZIG c++ -target $TARGET -mcpu=$MCPU"

mkdir _debug
cd _debug
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$DEBUG_STAGING" \
  -DCMAKE_PREFIX_PATH="$DEPS_LOCAL" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja

# Now cmake will use zig as the C/C++ compiler. We reset the environment variables
# so that installation and testing do not get affected by them.
unset CC
unset CXX

ninja install

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$DEBUG_STAGING/bin/zig"
ninja install

cd $WORKSPACE

"$DEBUG_STAGING/bin/zig" build -p stage3 -Denable-stage1 -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"

# simultaneously test building self-hosted without LLVM and with 32-bit arm
stage3/bin/zig build -Dtarget=arm-linux-musleabihf

echo "Looking for non-conforming code formatting..."
echo "Formatting errors can be fixed by running 'zig fmt' on the files printed here."
stage3/bin/zig fmt --check . --exclude test/cases/

stage3/bin/zig build test-compiler-rt      -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-behavior         -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-std              -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-universal-libc   -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-compare-output   -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-asm-link         -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-fmt              -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-translate-c      -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-run-translated-c -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-standalone       -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-cli              -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-cases            -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build test-link             -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build docs                  -fqemu -fwasmtime -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"

stage3/bin/zig build test-stack-traces -fqemu -fwasmtime -fstage1

# Produce the experimental std lib documentation.
mkdir -p "$RELEASE_STAGING/docs/std"
stage3/bin/zig test lib/std/std.zig \
  --zig-lib-dir lib \
  -femit-docs=$RELEASE_STAGING/docs/std \
  -fno-emit-bin

# Look for HTML errors.
tidy --drop-empty-elements no -qe zig-cache/langref.html

# Build release zig.
stage3/bin/zig build \
  --prefix "$RELEASE_STAGING" \
  --search-prefix "$DEPS_LOCAL" \
  -Dstatic-llvm \
  -Drelease \
  -Dstrip \
  -Dtarget="$TARGET" \
  -Denable-stage1

# Explicit exit helps show last command duration.
exit
