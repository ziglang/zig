// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-readobj -file-headers %tout | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .text
 .globl _start
_start:
 bx lr

// CHECK:  Flags [
// CHECK-NEXT:    0x1000000
// CHECK-NEXT:    0x4000000
// CHECK-NEXT:  ]
