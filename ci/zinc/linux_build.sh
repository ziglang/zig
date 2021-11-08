#!/bin/sh

. ./ci/zinc/linux_base.sh

ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9

# Build debug zig.
echo "BUILD debug zig with zig:$($ZIG version)"

export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"

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

ninja $JOBS install

ZIG=$DEBUG_STAGING/bin/zig

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$ZIG"
ninja $JOBS install

cd $WORKSPACE

# Build release zig.
echo "BUILD release zig with zig:$($ZIG version)"
export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"
mkdir _release
cd _release
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$RELEASE_STAGING" \
  -DCMAKE_PREFIX_PATH="$DEPS_LOCAL" \
  -DCMAKE_BUILD_TYPE=Release \
  -DZIG_TARGET_TRIPLE="$TARGET" \
  -DZIG_TARGET_MCPU="$MCPU" \
  -DZIG_STATIC=ON \
  -GNinja
unset CC
unset CXX
ninja $JOBS install

cd $WORKSPACE

# Look for non-conforming code formatting.
# Formatting errors can be fixed by running `zig fmt` on the files printed here.
$ZIG fmt --check .

# Explicit exit helps show last command duration.
exit
