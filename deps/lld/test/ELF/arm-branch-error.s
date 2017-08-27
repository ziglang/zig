// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-arm-abs.s -o %tfar
// RUN: not ld.lld  %t %tfar -o %t2 2>&1 | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .section .text, "ax",%progbits
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 // address of too_far symbols are just out of range of ARM branch with
 // 26-bit immediate field and an addend of -8
 bl  too_far1
 b   too_far2
 beq too_far3

// CHECK: R_ARM_CALL out of range
// CHECK-NEXT: R_ARM_JUMP24 out of range
// CHECK-NEXT: R_ARM_JUMP24 out of range
