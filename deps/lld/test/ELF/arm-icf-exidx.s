// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 --icf=all
// RUN: llvm-objdump -s -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s

 .syntax unified
 .section        .text.f,"axG",%progbits,f,comdat
f:
 .fnstart
 bx      lr
 .fnend

 .section        .text.g,"axG",%progbits,g,comdat
g:
 .fnstart
 bx      lr
 .fnend

 .section .text.h
 .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
 nop
 bx lr

// CHECK: Disassembly of section .text:
// CHECK-NEXT: f:
// CHECK-NEXT:    11000:        1e ff 2f e1     bx      lr
// CHECK: __aeabi_unwind_cpp_pr0:
// CHECK-NEXT:    11004:        00 f0 20 e3     nop
// CHECK-NEXT:    11008:        1e ff 2f e1     bx      lr

// CHECK: Contents of section .ARM.exidx:
// CHECK-NEXT:  100d4 2c0f0000 b0b0b080 280f0000 01000000
