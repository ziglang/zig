// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       . = SIZEOF_HEADERS; \
// RUN:       .text_low : { *(.text_low) *(.text_low2) } \
// RUN:       .text_high 0x2000000 : { *(.text_high) *(.text_high2) } \
// RUN:       } " > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck %s
// Simple test that we can support range extension thunks with linker scripts
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
// CHECK-NEXT:       9a:        00 f0 06 f8     bl      #12
// CHECK: __Thumbv7ABSLongThunk_high_target:
// CHECK-NEXT:       a0:        40 f2 01 0c     movw    r12, #1
// CHECK-NEXT:       a4:        c0 f2 00 2c     movt    r12, #512
// CHECK-NEXT:       a8:        60 47   bx      r12
// CHECK: __Thumbv7ABSLongThunk_high_target2:
// CHECK-NEXT:       aa:        40 f2 1d 0c     movw    r12, #29
// CHECK-NEXT:       ae:        c0 f2 00 2c     movt    r12, #512
// CHECK-NEXT:       b2:        60 47   bx      r12
// CHECK: low_target2:
// CHECK-NEXT:       b4:        ff f7 f4 ff     bl      #-24
// CHECK-NEXT:       b8:        ff f7 f7 ff     bl      #-18

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
// CHECK-NEXT:  2000004:        00 f0 05 f8     bl      #10
// CHECK: __Thumbv7ABSLongThunk_low_target:
// CHECK-NEXT:  2000008:        40 f2 97 0c     movw    r12, #151
// CHECK-NEXT:  200000c:        c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:  2000010:        60 47   bx      r12
// CHECK: __Thumbv7ABSLongThunk_low_target2:
// CHECK-NEXT:  2000012:        40 f2 b5 0c     movw    r12, #181
// CHECK-NEXT:  2000016:        c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:  200001a:        60 47   bx      r12
// CHECK: high_target2:
// CHECK-NEXT:  200001c:        ff f7 f4 ff     bl      #-24
// CHECK-NEXT:  2000020:        ff f7 f7 ff     bl      #-18
