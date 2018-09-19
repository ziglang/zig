// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s

// Test the R_ARM_SBREL32 relocation which calculates the offset of the Symbol
// from the static base. We define the static base to be the address of the
// segment containing the symbol
 .text
 .syntax unified

 .globl _start
 .p2align       2
 .type  _start,%function
_start:
        .fnstart
        bx lr

        .long   foo(sbrel)
        .long   foo2(sbrel)
        .long   foo3(sbrel)
        .long   foo4(sbrel)
// RW segment starts here
        .data
        .p2align 4
foo:    .word 10
foo2:   .word 20

        .bss
foo3:   .space 4
foo4:   .space 4

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:    11000:        1e ff 2f e1     bx      lr
// CHECK:         11004:        00 00 00 00     .word   0x00000000
// CHECK-NEXT:    11008:        04 00 00 00     .word   0x00000004
// CHECK-NEXT:    1100c:        08 00 00 00     .word   0x00000008
// CHECK-NEXT:    11010:        0c 00 00 00     .word   0x0000000c
