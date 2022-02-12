#!/bin/sh

. ./ci/zinc/linux_base.sh

ZIG=$DEBUG_STAGING/bin/zig

$ZIG test test/behavior.zig -fno-stage1 -I test -fLLVM
$ZIG test test/behavior.zig -fno-stage1 -I test -fLLVM -target aarch64-linux --test-cmd qemu-aarch64 --test-cmd-bin
$ZIG test test/behavior.zig -fno-stage1 -I test -ofmt=c
$ZIG test test/behavior.zig -fno-stage1 -I test -target wasm32-wasi --test-cmd wasmtime --test-cmd-bin
$ZIG test test/behavior.zig -fno-stage1 -I test -target   arm-linux --test-cmd qemu-arm --test-cmd-bin
$ZIG test test/behavior.zig -fno-stage1 -I test

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
