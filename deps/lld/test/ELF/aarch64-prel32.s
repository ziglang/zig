// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs255.s -o %t255.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs256.s -o %t256.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs257.s -o %t257.o

.globl _start
_start:
.data
  .word foo - . + 0x100200eff
  .word foo - . - 0x7fdff0fc

// Note: If this test fails, it probably happens because of
//       the change of the address of the .data section.
//       You may found the correct address in the aarch64_abs32.s test,
//       if it is already fixed. Then, update addends accordingly.
// RUN: ld.lld -z max-page-size=4096 %t.o %t256.o -o %t2
// RUN: llvm-objdump -s -section=.data %t2 | FileCheck %s

// CHECK: Contents of section .data:
// 201000: S = 0x100, A = 0x100200eff, P = 0x201000
//         S + A - P = 0xffffffff
// 201004: S = 0x100, A = -0x7fdff0fc, P = 0x201004
//         S + A - P = 0x80000000
// CHECK-NEXT: 201000 ffffffff 00000080

// RUN: not ld.lld -z max-page-size=4096 %t.o %t255.o -o %t2 2>&1 | FileCheck %s --check-prefix=OVERFLOW1
// OVERFLOW1: relocation R_AARCH64_PREL32 out of range: -2147483649 is not in [-2147483648, 2147483647]

// RUN: not ld.lld -z max-page-size=4096 %t.o %t257.o -o %t2 2>&1 | FileCheck %s --check-prefix=OVERFLOW2
// OVERFLOW2: relocation R_AARCH64_PREL32 out of range: 4294967296 is not in [-2147483648, 2147483647]
