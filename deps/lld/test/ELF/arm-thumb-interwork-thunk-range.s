// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t -image-base=0x80000000

// Test that when the thunk is at a high address we don't get confused with it
// being out of range.

.thumb
.global _start
_start:
b.w foo

.arm
.weak foo
foo:
