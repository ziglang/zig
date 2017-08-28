// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs255.s -o %t255.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs256.s -o %t256.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %S/Inputs/abs257.s -o %t257.o

.globl _start
_start:
.data
  .hword foo + 0xfeff
  .hword foo - 0x8100

// RUN: ld.lld %t.o %t256.o -o %t2
// RUN: llvm-objdump -s -section=.data %t2 | FileCheck %s

// CHECK: Contents of section .data:
// 11000: S = 0x100, A = 0xfeff
//        S + A = 0xffff
// 11002: S = 0x100, A = -0x8100
//        S + A = 0x8000
// CHECK-NEXT: 20000 ffff0080

// RUN: not ld.lld %t.o %t255.o -o %t2
//   | FileCheck %s --check-prefix=OVERFLOW
// RUN: not ld.lld %t.o %t257.o -o %t2
//   | FileCheck %s --check-prefix=OVERFLOW
// OVERFLOW: Relocation R_AARCH64_ABS16 out of range
