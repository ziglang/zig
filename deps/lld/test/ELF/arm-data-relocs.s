// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/abs256.s -o %t256.o
// RUN: ld.lld %t %t256.o -o %t2
// RUN: llvm-objdump -d %t2 | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .globl _start
_start:
 .section .R_ARM_ABS32POS, "ax",%progbits
 .word foo + 0x24

// S = 0x100, A = 0x24
// S + A = 0x124
// CHECK: Disassembly of section .R_ARM_ABS32POS:
// CHECK: 11000: 24 01 00 00
 .section .R_ARM_ABS32NEG, "ax",%progbits
 .word foo - 0x24
// S = 0x100, A = -0x24
// CHECK: Disassembly of section .R_ARM_ABS32NEG:
// CHECK: 11004: dc 00 00 00
