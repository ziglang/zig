// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: not ld.lld %t -o /dev/null 2>&1 | FileCheck %s
 .syntax unified
 .balign 0x1000
 .thumb
 .text
 .globl _start
 .type _start, %function
_start:
 bx lr

 .section .text.large1, "ax", %progbits
 .balign 4
.space (17 * 1024 * 1024)
 bl _start
.space (17 * 1024 * 1024)

// CHECK: error: InputSection too large for range extension thunk {{.*}}.text.large1
