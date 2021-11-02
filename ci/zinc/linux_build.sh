#!/bin/sh

set -x
set -e

# Probe CPU/brand details.
echo "lscpu:"
(lscpu | sed 's,^,  : ,') 1>&2

pwd
(env | sort | sed 's,^,  : ,') 1>&2

WORKSPACE="$DRONE_WORKSPACE"
LOCAL="/deps/local"
ZIG="$LOCAL/bin/zig"
ARCH="$(uname -m)"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"
JOBS="-j$(nproc)"
export PATH=/deps/local/bin:$PATH

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
  -DCMAKE_INSTALL_PREFIX="$(pwd)/staging" \
  -DCMAKE_PREFIX_PATH="$LOCAL" \
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

ZIG=$(pwd)/staging/bin/zig

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$ZIG"
ninja $JOBS install

cd $WORKSPACE

# Build release zig.
echo "BUILD release zig with zig:$($ZIG version)"
echo "zig version: $($ZIG version)"
export CC="$ZIG cc -target $TARGET -mcpu=$MCPU"
export CXX="$ZIG c++ -target $TARGET -mcpu=$MCPU"
mkdir _release
cd _release
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$(pwd)/staging" \
  -DCMAKE_PREFIX_PATH="$LOCAL" \
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

$ZIG test test/behavior.zig -fno-stage1 -fLLVM -I test

$ZIG build test-behavior         -Denable-qemu -Denable-wasmtime
$ZIG build test-compiler-rt      -Denable-qemu -Denable-wasmtime
$ZIG build test-std              -Denable-qemu -Denable-wasmtime
$ZIG build test-minilibc         -Denable-qemu -Denable-wasmtime
$ZIG build test-compare-output   -Denable-qemu -Denable-wasmtime
$ZIG build test-standalone       -Denable-qemu -Denable-wasmtime
$ZIG build test-stack-traces     -Denable-qemu -Denable-wasmtime
$ZIG build test-cli              -Denable-qemu -Denable-wasmtime
$ZIG build test-asm-link         -Denable-qemu -Denable-wasmtime
$ZIG build test-runtime-safety   -Denable-qemu -Denable-wasmtime
$ZIG build test-translate-c      -Denable-qemu -Denable-wasmtime
$ZIG build test-run-translated-c -Denable-qemu -Denable-wasmtime
$ZIG build docs                  -Denable-qemu -Denable-wasmtime
$ZIG build # test building self-hosted without LLVM
$ZIG build test-fmt              -Denable-qemu -Denable-wasmtime
$ZIG build test-stage2           -Denable-qemu -Denable-wasmtime

# Look for HTML errors.
tidy --drop-empty-elements no -qe zig-cache/langref.html

# The remainder of this script is for master branch only.
if [ -n "$DRONE_PULL_REQUEST" ]; then
  exit 0
fi

STAGING=_release/staging

# Produce the experimental std lib documentation.
mkdir -p $STAGING/docs/std
$ZIG test lib/std/std.zig \
  --zig-lib-dir lib \
  -femit-docs=$STAGING/docs/std \
  -fno-emit-bin

cp LICENSE $STAGING/
cp zig-cache/langref.html $STAGING/docs/

# Remove the unnecessary bin dir in $prefix/bin/zig
mv $STAGING/bin/zig $STAGING/
rmdir $STAGING/bin

# Remove the unnecessary zig dir in $prefix/lib/zig/std/std.zig
mv $STAGING/lib/zig $STAGING/lib2
rmdir $STAGING/lib
mv $STAGING/lib2 $STAGING/lib

VERSION=$($STAGING/zig version)
BASENAME="zig-linux-$ARCH-$VERSION"
TARBALL="${BASENAME}.tar.xz"
mv "$STAGING" "$BASENAME"
tar cfJ "$TARBALL" "$BASENAME"
ls -l "$TARBALL"

# TODO: push artifact/meta somewhere
## mv "$DOWNLOADSECUREFILE_SECUREFILEPATH" "$HOME/.s3cfg"
## s3cmd put -P --add-header="cache-control: public, max-age=31536000, immutable" "$TARBALL" s3://ziglang.org/builds/
##
## SHASUM=$(sha256sum $TARBALL | cut '-d ' -f1)
## BYTESIZE=$(wc -c < $TARBALL)
##
## JSONFILE="linux-$GITBRANCH.json"
## touch $JSONFILE
## echo "{\"tarball\": \"$TARBALL\"," >>$JSONFILE
## echo "\"shasum\": \"$SHASUM\"," >>$JSONFILE
## echo "\"size\": \"$BYTESIZE\"}" >>$JSONFILE
##
## s3cmd put -P --add-header="Cache-Control: max-age=0, must-revalidate" "$JSONFILE" "s3://ziglang.org/builds/$JSONFILE"
## s3cmd put -P "$JSONFILE" "s3://ziglang.org/builds/$ARCH-linux-$VERSION.json"
##
## # `set -x` causes these variables to be mangled.
## # See https://developercommunity.visualstudio.com/content/problem/375679/pipeline-variable-incorrectly-inserts-single-quote.html
## set +x
## echo "##vso[task.setvariable variable=tarball;isOutput=true]$TARBALL"
## echo "##vso[task.setvariable variable=shasum;isOutput=true]$SHASUM"
## echo "##vso[task.setvariable variable=bytesize;isOutput=true]$BYTESIZE"
## echo "##vso[task.setvariable variable=version;isOutput=true]$VERSION"
