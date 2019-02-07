// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       . = SIZEOF_HEADERS; \
// RUN:       .text_low : { *(.text_low) *(.text_low2) } \
// RUN:       .text_high 0x2000000 : { *(.text_high) *(.text_high2) } \
// RUN:       } " > %t.script
// RUN: ld.lld --pic-veneer --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck %s

// Test that we can force generation of position independent thunks even when
// inputs are not pic.

 .syntax unified
 .section .text_low, "ax", %progbits
 .thumb
 .globl _start
_start: bx lr
 .globl low_target
 .type low_target, %function
low_target:
 bl high_target
 bl high_target2

 .section .text_low2, "ax", %progbits
 .thumb
 .globl low_target2
 .type low_target2, %function
low_target2:
 bl high_target
 bl high_target2

// CHECK: Disassembly of section .text_low:
// CHECK-NEXT: _start:
// CHECK-NEXT:       94:        70 47   bx      lr
// CHECK: low_target:
// CHECK-NEXT:       96:        00 f0 03 f8     bl      #6
// CHECK-NEXT:       9a:        00 f0 07 f8     bl      #14
// CHECK-NEXT:       9e:        d4 d4   bmi     #-88
// CHECK: __ThumbV7PILongThunk_high_target:
// CHECK-NEXT:       a0:        4f f6 55 7c     movw    r12, #65365
// CHECK-NEXT:       a4:        c0 f2 ff 1c     movt    r12, #511
// CHECK-NEXT:       a8:        fc 44   add     r12, pc
// CHECK-NEXT:       aa:        60 47   bx      r12
// CHECK: __ThumbV7PILongThunk_high_target2:
// CHECK-NEXT:       ac:        4f f6 69 7c     movw    r12, #65385
// CHECK-NEXT:       b0:        c0 f2 ff 1c     movt    r12, #511
// CHECK-NEXT:       b4:        fc 44   add     r12, pc
// CHECK-NEXT:       b6:        60 47   bx      r12
// CHECK: low_target2:
// CHECK-NEXT:       b8:        ff f7 f2 ff     bl      #-28
// CHECK-NEXT:       bc:        ff f7 f6 ff     bl      #-20


 .section .text_high, "ax", %progbits
 .thumb
 .globl high_target
 .type high_target, %function
high_target:
 bl low_target
 bl low_target2

 .section .text_high2, "ax", %progbits
 .thumb
 .globl high_target2
 .type high_target2, %function
high_target2:
 bl low_target
 bl low_target2

// CHECK: Disassembly of section .text_high:
// CHECK-NEXT: high_target:
// CHECK-NEXT:  2000000:        00 f0 02 f8     bl      #4
// CHECK-NEXT:  2000004:        00 f0 06 f8     bl      #12
// CHECK: __ThumbV7PILongThunk_low_target:
// CHECK-NEXT:  2000008:        40 f2 83 0c     movw    r12, #131
// CHECK-NEXT:  200000c:        cf f6 00 6c     movt    r12, #65024
// CHECK-NEXT:  2000010:        fc 44   add     r12, pc
// CHECK-NEXT:  2000012:        60 47   bx      r12
// CHECK: __ThumbV7PILongThunk_low_target2:
// CHECK-NEXT:  2000014:        40 f2 99 0c     movw    r12, #153
// CHECK-NEXT:  2000018:        cf f6 00 6c     movt    r12, #65024
// CHECK-NEXT:  200001c:        fc 44   add     r12, pc
// CHECK-NEXT:  200001e:        60 47   bx      r12
// CHECK: high_target2:
// CHECK-NEXT:  2000020:        ff f7 f2 ff     bl      #-28
// CHECK-NEXT:  2000024:        ff f7 f6 ff     bl      #-20
