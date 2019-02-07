// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs255.s -o %t255.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs256.s -o %t256.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs257.s -o %t257.o

.globl _start
_start:
.data
  .word foo + 0xfffffeff
  .word foo - 0x80000100

// RUN: ld.lld %t.o %t256.o -o %t2
// RUN: llvm-objdump -s -section=.data %t2 | FileCheck %s

// CHECK: Contents of section .data:
// 210000: S = 0x100, A = 0xfffffeff
//         S + A = 0xffffffff
// 210004: S = 0x100, A = -0x80000100
//         S + A = 0x80000000
// CHECK-NEXT: 210000 ffffffff 00000080

// RUN: not ld.lld %t.o %t255.o -o %t2 2>&1 | FileCheck %s --check-prefix=OVERFLOW1
// OVERFLOW1: relocation R_AARCH64_ABS32 out of range: -2147483649 is not in [-2147483648, 2147483647]

// RUN: not ld.lld %t.o %t257.o -o %t2 2>&1 | FileCheck %s --check-prefix=OVERFLOW2
// OVERFLOW2: relocation R_AARCH64_ABS32 out of range: 4294967296 is not in [-2147483648, 2147483647]
