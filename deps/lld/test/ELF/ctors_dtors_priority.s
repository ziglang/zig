// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/ctors_dtors_priority1.s -o %t-crtbegin.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/ctors_dtors_priority2.s -o %t2
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/ctors_dtors_priority3.s -o %t-crtend.o
// RUN: ld.lld %t1 %t2 %t-crtend.o %t-crtbegin.o -o %t.exe
// RUN: llvm-objdump -s %t.exe | FileCheck %s

.globl _start
_start:
  nop

.section .ctors, "aw", @progbits
  .quad 1
.section .ctors.100, "aw", @progbits
  .quad 2
.section .ctors.005, "aw", @progbits
  .quad 3
.section .ctors, "aw", @progbits
  .quad 4
.section .ctors, "aw", @progbits
  .quad 5

.section .dtors, "aw", @progbits
  .quad 0x11
.section .dtors.100, "aw", @progbits
  .quad 0x12
.section .dtors.005, "aw", @progbits
  .quad 0x13
.section .dtors, "aw", @progbits
  .quad 0x14
.section .dtors, "aw", @progbits
  .quad 0x15

// CHECK:      Contents of section .ctors:
// CHECK-NEXT: 202000 a1000000 00000000 01000000 00000000
// CHECK-NEXT: 202010 04000000 00000000 05000000 00000000
// CHECK-NEXT: 202020 b1000000 00000000 03000000 00000000
// CHECK-NEXT: 202030 02000000 00000000 c1000000 00000000

// CHECK:      Contents of section .dtors:
// CHECK-NEXT: 202040 a2000000 00000000 11000000 00000000
// CHECK-NEXT: 202050 14000000 00000000 15000000 00000000
// CHECK-NEXT: 202060 b2000000 00000000 13000000 00000000
// CHECK-NEXT: 202070 12000000 00000000 c2000000 00000000
