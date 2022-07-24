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

STAGE1_ZIG="$DEBUG_STAGING/bin/zig"

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$STAGE1_ZIG"
ninja install

cd $WORKSPACE

echo "Looking for non-conforming code formatting..."
echo "Formatting errors can be fixed by running 'zig fmt' on the files printed here."
$STAGE1_ZIG fmt --check . --exclude test/cases/

$STAGE1_ZIG    build -p stage2 -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage2/bin/zig build -p stage3 -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"
stage3/bin/zig build # test building self-hosted without LLVM
stage3/bin/zig build -Dtarget=arm-linux-musleabihf # test building self-hosted for 32-bit arm

stage3/bin/zig build test-compiler-rt    -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-behavior       -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-std            -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-universal-libc -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-compare-output -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-asm-link       -fqemu -fwasmtime -Denable-llvm
stage3/bin/zig build test-fmt            -fqemu -fwasmtime -Denable-llvm

$STAGE1_ZIG build test-standalone       -fqemu -fwasmtime
$STAGE1_ZIG build test-stack-traces     -fqemu -fwasmtime
$STAGE1_ZIG build test-cli              -fqemu -fwasmtime
$STAGE1_ZIG build test-translate-c      -fqemu -fwasmtime
$STAGE1_ZIG build test-run-translated-c -fqemu -fwasmtime
$STAGE1_ZIG build docs                  -fqemu -fwasmtime
$STAGE1_ZIG build test-cases            -fqemu -fwasmtime

# Produce the experimental std lib documentation.
mkdir -p "$RELEASE_STAGING/docs/std"
$STAGE1_ZIG test lib/std/std.zig \
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
  -Dstage1

# Explicit exit helps show last command duration.
exit
