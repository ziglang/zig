// REQUIRES: x86

// This is a test for R_X86_64_PC8 and R_X86_64_PC16.

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/x86-64-pcrel.s -o %t2.o
// RUN: ld.lld -o %t.exe %t1.o %t2.o
// RUN: llvm-objdump -s %t.exe | FileCheck %s

// CHECK:      Contents of section .text:
// CHECK-NEXT: 2000cccc cccccccc cccccccc cccccccc
// CHECK-NEXT: 20cccccc cccccccc cccccccc cccccccc
// CHECK-NEXT: e0ffcccc cccccccc cccccccc cccccccc
// CHECK-NEXT: e0cccccc cccccccc cccccccc cccccccc

.globl _start
_start:

.word foo - _start
.fill 14,1,0xcc

.byte foo - _start
.fill 15,1,0xcc
