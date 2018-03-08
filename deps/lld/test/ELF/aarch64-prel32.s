// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs255.s -o %t255.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs256.s -o %t256.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs257.s -o %t257.o

.globl _start
_start:
.data
  .word foo - . + 0x100010eff
  .word foo - . - 0x7ffef0fc

// Note: If this test fails, it probably happens because of
//       the change of the address of the .data section.
//       You may found the correct address in the aarch64_abs32.s test,
//       if it is already fixed. Then, update addends accordingly.
// RUN: ld.lld -z max-page-size=4096 %t.o %t256.o -o %t2
// RUN: llvm-objdump -s -section=.data %t2 | FileCheck %s

// CHECK: Contents of section .data:
// 11000: S = 0x100, A = 0x100010eff, P = 0x11000
//        S + A - P = 0xffffffff
// 11004: S = 0x100, A = -0x7ffef0fc, P = 0x11004
//        S + A - P = 0x80000000
// CHECK-NEXT: 11000 ffffffff 00000080

// RUN: not ld.lld %t.o %t255.o -o %t2
//   | FileCheck %s --check-prefix=OVERFLOW
// RUN: not ld.lld %t.o %t257.o -o %t2
//   | FileCheck %s --check-prefix=OVERFLOW
// OVERFLOW: Relocation R_AARCH64_PREL32 out of range: 18446744071562006527 is not in [-2147483648, 4294967295]
