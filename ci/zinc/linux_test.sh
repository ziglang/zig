#!/bin/sh

. ./ci/zinc/linux_base.sh

ZIG="$DEPS_LOCAL/bin/zig"
TARGET="${ARCH}-linux-musl"
MCPU="baseline"

# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9

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

ninja install

ZIG="$DEBUG_STAGING/bin/zig"

# Here we rebuild zig but this time using the Zig binary we just now produced to
# build zig1.o rather than relying on the one built with stage0. See
# https://github.com/ziglang/zig/issues/6830 for more details.
cmake .. -DZIG_EXECUTABLE="$ZIG"
ninja install

cd $WORKSPACE

# Look for non-conforming code formatting.
# Formatting errors can be fixed by running `zig fmt` on the files printed here.
$ZIG fmt --check . --exclude test/compile_errors/

# Build stage2 standalone so that we can test stage2 against stage2 compiler-rt.
$ZIG             build -p stage2 -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"

# Ensure that stage2 can build itself.
./stage2/bin/zig build -p stage3 -Dstatic-llvm -Dtarget=native-native-musl --search-prefix "$DEPS_LOCAL"

stage2/bin/zig test test/behavior.zig -I test -fLLVM
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM
stage2/bin/zig test test/behavior.zig -I test -fLLVM    -target aarch64-linux --test-cmd qemu-aarch64 --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM -target aarch64-linux --test-cmd qemu-aarch64 --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -ofmt=c
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM -target  wasm32-wasi  --test-cmd wasmtime     --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -fLLVM    -target  wasm32-wasi  --test-cmd wasmtime     --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM -target     arm-linux --test-cmd qemu-arm     --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -fLLVM    -target aarch64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM -target aarch64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test -fLLVM    -target  x86_64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test -fno-LLVM -target  x86_64-macos --test-no-exec

$ZIG build test-behavior         -fqemu -fwasmtime
$ZIG build test-compiler-rt      -fqemu -fwasmtime
$ZIG build test-std              -fqemu -fwasmtime
$ZIG build test-minilibc         -fqemu -fwasmtime
$ZIG build test-compare-output   -fqemu -fwasmtime
$ZIG build test-standalone       -fqemu -fwasmtime
$ZIG build test-stack-traces     -fqemu -fwasmtime
$ZIG build test-cli              -fqemu -fwasmtime
$ZIG build test-asm-link         -fqemu -fwasmtime
$ZIG build test-runtime-safety   -fqemu -fwasmtime
$ZIG build test-translate-c      -fqemu -fwasmtime
$ZIG build test-run-translated-c -fqemu -fwasmtime
$ZIG build docs                  -fqemu -fwasmtime
$ZIG build # test building self-hosted without LLVM
$ZIG build -Dtarget=arm-linux-musleabihf # test building self-hosted for 32-bit arm
$ZIG build test-fmt              -fqemu -fwasmtime
$ZIG build test-stage2           -fqemu -fwasmtime

# Produce the experimental std lib documentation.
mkdir -p "$RELEASE_STAGING/docs/std"
$ZIG test lib/std/std.zig \
  --zig-lib-dir lib \
  -femit-docs=$RELEASE_STAGING/docs/std \
  -fno-emit-bin

# Look for HTML errors.
tidy --drop-empty-elements no -qe zig-cache/langref.html

# Build release zig.
$ZIG build \
  --prefix "$RELEASE_STAGING" \
  --search-prefix "$DEPS_LOCAL" \
  -Dstatic-llvm \
  -Drelease \
  -Dstrip \
  -Dtarget="$TARGET" \
  -Dstage1

# Explicit exit helps show last command duration.
exit
