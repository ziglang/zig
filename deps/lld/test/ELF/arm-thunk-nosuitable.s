// REQUIRES: arm
// RUN: llvm-mc %s --arm-add-build-attributes --triple=armv7a-linux-gnueabihf --filetype=obj -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-objdump -triple=thumbv7a-linux-gnueabihf -d -start-address=2166784 -stop-address=2166794 %t | FileCheck %s

        // Create a conditional branch too far away from a precreated thunk
        // section. This will need a thunk section created within range.
        .syntax unified
        .thumb

        .section .text.0, "ax", %progbits
        .space 2 * 1024 * 1024
        .globl _start
        .type _start, %function
_start:
        // Range of +/- 1 Megabyte, new ThunkSection will need creating after
        // .text.1
        beq.w target
        .section .text.1, "ax", %progbits
        bx lr

// CHECK: _start:
// CHECK-NEXT:   211000:        00 f0 00 80     beq.w   #0
// CHECK: __Thumbv7ABSLongThunk_target:
// CHECK-NEXT:   211004:        00 f0 01 90     b.w     #12582914
// CHECK:        211008:        70 47   bx      lr

        .section .text.2, "ax", %progbits
        .space 12 * 1024 * 1024
        .globl target
        .type target, %function
target: bx lr
