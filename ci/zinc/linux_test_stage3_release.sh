#!/bin/sh

. ./ci/zinc/linux_base.sh

OLD_ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"

echo "building stage3-release with zig version $($OLD_ZIG version)"

export CC="$OLD_ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$OLD_ZIG c++ -target $TARGET -mcpu=$MCPU"

mkdir build-release
cd build-release
STAGE2_PREFIX="$(pwd)/stage2"
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$STAGE2_PREFIX" \
  -DCMAKE_PREFIX_PATH="$DEPS_LOCAL" \
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

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$STAGE2_PREFIX/bin/zig"
ninja install

# This is the binary we will distribute. We intentionally test this one in this
# script. If any test failures occur, hopefully they also occur in the debug
# version of this script for easier troubleshooting. This prevents distribution
# of a Zig binary that passes tests in debug mode but has a miscompilation in
# release mode.
"$STAGE2_PREFIX/bin/zig" build \
  --prefix "$RELEASE_STAGING" \
  --search-prefix "$DEPS_LOCAL" \
  -Dstatic-llvm \
  -Drelease \
  -Dstrip \
  -Dtarget="$TARGET" \
  -Denable-stage1

cd $WORKSPACE

ZIG="$RELEASE_STAGING/bin/zig"

$ZIG build test \
  -fqemu \
  -fwasmtime \
  -Dstatic-llvm \
  -Dtarget=native-native-musl \
  --search-prefix "$DEPS_LOCAL"

# Produce the experimental std lib documentation.
mkdir -p "$RELEASE_STAGING/docs/std"
$ZIG test lib/std/std.zig \
  --zig-lib-dir lib \
  -femit-docs=$RELEASE_STAGING/docs/std \
  -fno-emit-bin

cp LICENSE $RELEASE_STAGING/
cp zig-cache/langref.html $RELEASE_STAGING/docs/

# Look for HTML errors.
tidy --drop-empty-elements no -qe $RELEASE_STAGING/docs/langref.html

# Explicit exit helps show last command duration.
exit
