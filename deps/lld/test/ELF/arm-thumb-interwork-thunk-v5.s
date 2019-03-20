// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv5-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-objdump -d %t2 -triple=armv5-none-linux-gnueabi | FileCheck -check-prefix=CHECK-ARM %s
// RUN: llvm-objdump -d %t2 -triple=thumbv5-none-linux-gnueabi | FileCheck -check-prefix=CHECK-THUMB %s
// RUN: ld.lld %t -o %t3 --shared
// RUN: llvm-objdump -d %t3 -triple=armv5-none-linux-gnueabi | FileCheck -check-prefix=CHECK-ARM-PI %s
// RUN: llvm-objdump -d %t3 -triple=thumbv5-none-linux-gnueabi | FileCheck -check-prefix=CHECK-THUMB-PI %s

// Test ARM Thumb Interworking on older Arm architectures using Thunks that do
// not use MOVT/MOVW instructions.
// For pure interworking (not considering range extension) there is only the
// case of an Arm B to a Thumb Symbol to consider as in older Arm architectures
// there is no Thumb B.w that we can intercept with a Thunk and we still assume
// support for the blx instruction for Thumb BL and BLX to an Arm symbol.
        .arm
        .text
        .syntax unified
        .cpu    arm10tdmi

        .text
        .globl _start
        .type _start, %function
        .balign 0x1000
_start:
        b thumb_func
        bl thumb_func
        blx thumb_func
        bx lr

// CHECK-ARM: _start:
// CHECK-ARM-NEXT: 11000: 03 00 00 ea     b       #12 <__ARMv5ABSLongThunk_thumb_func>
// CHECK-ARM-NEXT: 11004: 01 00 00 fa     blx     #4 <thumb_func>
// CHECK-ARM-NEXT: 11008: 00 00 00 fa     blx     #0 <thumb_func>
// CHECK-ARM-NEXT: 1100c: 1e ff 2f e1     bx      lr

// CHECK-THUMB: thumb_func:
// CHECK-THUMB-NEXT: 11010: 70 47   bx      lr

// CHECK-ARM: __ARMv5ABSLongThunk_thumb_func:
// CHECK-ARM-NEXT: 11014: 04 f0 1f e5     ldr     pc, [pc, #-4]
// CHECK-ARM: $d:
// CHECK-ARM-NEXT: 11018: 11 10 01 00     .word   0x00011011

// CHECK-ARM-PI: _start:
// CHECK-ARM-PI-NEXT: 1000: 03 00 00 ea     b       #12 <__ARMV5PILongThunk_thumb_func>
// CHECK-ARM-PI-NEXT: 1004: 01 00 00 fa     blx     #4 <thumb_func>
// CHECK-ARM-PI-NEXT: 1008: 00 00 00 fa     blx     #0 <thumb_func>
// CHECK-ARM-PI-NEXT: 100c: 1e ff 2f e1     bx      lr

// CHECK-THUMB-PI: thumb_func:
// CHECK-THUMB-PI-NEXT: 1010: 70 47   bx      lr

// CHECK-ARM-PI: __ARMV5PILongThunk_thumb_func:
// CHECK-ARM-PI-NEXT: 1014: 04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-ARM-PI-NEXT: 1018: 0c c0 8f e0     add     r12, pc, r12
// CHECK-ARM-PI-NEXT: 101c: 1c ff 2f e1     bx      r12
// CHECK-ARM-PI: $d:
// CHECK-ARM-PI-NEXT: 1020: f1 ff ff ff     .word   0xfffffff1

        .section .text.1, "ax", %progbits
        .thumb
        .hidden thumb_func
        .type thumb_func, %function
thumb_func:
        bx lr
