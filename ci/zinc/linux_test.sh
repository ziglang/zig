#!/bin/sh

. ./ci/zinc/linux_base.sh

ZIG=$DEBUG_STAGING/bin/zig

$ZIG test test/behavior.zig -fno-stage1 -fLLVM -I test
$ZIG test test/behavior.zig -fno-stage1 -ofmt=c -I test

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
$ZIG build -Dtarget=arm-linux-musleabihf # test building self-hosted for 32-bit arm
$ZIG build test-fmt              -Denable-qemu -Denable-wasmtime
$ZIG build test-stage2           -Denable-qemu -Denable-wasmtime

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
