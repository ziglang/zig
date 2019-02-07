// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       . = SIZEOF_HEADERS; \
// RUN:       .text_low : { *(.text_low) *(.text_low2) . = . + 0x2000000 ; *(.text_high) *(.text_high2) } \
// RUN:       } " > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d %t2 -start-address=148 -stop-address=188 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t2 -start-address=33554620 -stop-address=33554654 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
// Test that range extension thunks can handle location expressions within
// a Section Description
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
// CHECK1: Disassembly of section .text_low:
// CHECK1-NEXT: _start:
// CHECK1-NEXT:       94:       70 47   bx      lr
// CHECK1: low_target:
// CHECK1-NEXT:       96:       00 f0 03 f8     bl      #6
// CHECK1-NEXT:       9a:       00 f0 06 f8     bl      #12
// CHECK1: __Thumbv7ABSLongThunk_high_target:
// CHECK1-NEXT:       a0:       40 f2 bd 0c     movw    r12, #189
// CHECK1-NEXT:       a4:       c0 f2 00 2c     movt    r12, #512
// CHECK1-NEXT:       a8:       60 47   bx      r12
// CHECK1: __Thumbv7ABSLongThunk_high_target2:
// CHECK1-NEXT:       aa:       40 f2 d9 0c     movw    r12, #217
// CHECK1-NEXT:       ae:       c0 f2 00 2c     movt    r12, #512
// CHECK1-NEXT:       b2:       60 47   bx      r12
// CHECK1: low_target2:
// CHECK1-NEXT:       b4:       ff f7 f4 ff     bl      #-24
// CHECK1-NEXT:       b8:       ff f7 f7 ff     bl      #-18

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

// CHECK2: high_target:
// CHECK2-NEXT:  20000bc:       00 f0 02 f8     bl      #4
// CHECK2-NEXT:  20000c0:       00 f0 05 f8     bl      #10
// CHECK2: __Thumbv7ABSLongThunk_low_target:
// CHECK2-NEXT:  20000c4:       40 f2 97 0c     movw    r12, #151
// CHECK2-NEXT:  20000c8:       c0 f2 00 0c     movt    r12, #0
// CHECK2-NEXT:  20000cc:       60 47   bx      r12
// CHECK2: __Thumbv7ABSLongThunk_low_target2:
// CHECK2-NEXT:  20000ce:       40 f2 b5 0c     movw    r12, #181
// CHECK2-NEXT:  20000d2:       c0 f2 00 0c     movt    r12, #0
// CHECK2-NEXT:  20000d6:       60 47   bx      r12
// CHECK2: high_target2:
// CHECK2-NEXT:  20000d8:       ff f7 f4 ff     bl      #-24
// CHECK2-NEXT:  20000dc:       ff f7 f7 ff     bl      #-18
