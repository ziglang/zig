#!/bin/sh

. ./ci/zinc/linux_base.sh

ZIG=$DEBUG_STAGING/bin/zig

# Build stage2 standalone so that we can test stage2 against stage2 compiler-rt.
$ZIG build -p stage2 -Denable-llvm

stage2/bin/zig test test/behavior.zig -I test -fLLVM
stage2/bin/zig test test/behavior.zig -I test
stage2/bin/zig test test/behavior.zig -I test -fLLVM -target aarch64-linux --test-cmd qemu-aarch64 --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test        -target aarch64-linux --test-cmd qemu-aarch64 --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -ofmt=c
stage2/bin/zig test test/behavior.zig -I test        -target  wasm32-wasi  --test-cmd wasmtime     --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test        -target     arm-linux --test-cmd qemu-arm     --test-cmd-bin
stage2/bin/zig test test/behavior.zig -I test -fLLVM -target aarch64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test        -target aarch64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test -fLLVM -target  x86_64-macos --test-no-exec
stage2/bin/zig test test/behavior.zig -I test        -target  x86_64-macos --test-no-exec

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
mkdir -p $RELEASE_STAGING/docs/std
$ZIG test lib/std/std.zig \
  --zig-lib-dir lib \
  -femit-docs=$RELEASE_STAGING/docs/std \
  -fno-emit-bin

# Look for HTML errors.
tidy --drop-empty-elements no -qe zig-cache/langref.html

# Explicit exit helps show last command duration.
exit
