// REQUIRES: arm
// RUN: llvm-mc -filetype=obj  -arm-add-build-attributes -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -S %t.so | FileCheck %s

// Test that when all the .ARM.exidx sections are merged into a single
// synthetic EXIDX_CANTUNWIND entry we can still set the SHF_LINK_ORDER
// link.
 .syntax unified
 .section .text.1, "ax", %progbits
 .globl f1
 .type f1, %function
f1:
 bx lr

 .section .text.2, "ax", %progbits
 .globl f2
 .type f2, %function
f2:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// CHECK:      Name: .ARM.exidx
// CHECK-NEXT: Type: SHT_ARM_EXIDX
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_LINK_ORDER
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link: [[INDEX:.*]]

// CHECK:      Index: [[INDEX]]
// CHECK-NEXT: Name: .text
