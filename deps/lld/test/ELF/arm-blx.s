// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-arm-thumb-abs.s -o %tfar
// RUN: echo "SECTIONS { \
// RUN:          . = 0xb4; \
// RUN:          .callee1 : { *(.callee_low) } \
// RUN:          .callee2 : { *(.callee_arm_low) } \
// RUN:          .caller : { *(.text) } \
// RUN:          .callee3 : { *(.callee_high) } \
// RUN:          .callee4 : { *(.callee_arm_high) } } " > %t.script
// RUN: ld.lld --script %t.script %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-ARM %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-THUMB %s
// REQUIRES: arm

// Test BLX instruction is chosen for ARM BL/BLX instruction and Thumb callee
// Using two callees to ensure at least one has 2-byte alignment.
 .syntax unified
 .thumb
 .section .callee_low, "ax",%progbits
 .align 2
 .type callee_low,%function
callee_low:
 bx lr
 .type callee_low2, %function
callee_low2:
 bx lr

 .section .callee_arm_low, "ax",%progbits
 .arm
 .balign 0x100
 .type callee_arm_low,%function
 .align 2
callee_arm_low:
  bx lr

.section .text, "ax",%progbits
 .arm
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 bl  callee_low
 blx callee_low
 bl  callee_low2
 blx callee_low2
 bl  callee_high
 blx callee_high
 bl  callee_high2
 blx callee_high2
 bl  blx_far
 blx blx_far2
// blx to ARM instruction should be written as a BL
 bl  callee_arm_low
 blx callee_arm_low
 bl  callee_arm_high
 blx callee_arm_high
 bx lr

 .section .callee_high, "ax",%progbits
 .balign 0x100
 .thumb
 .type callee_high,%function
callee_high:
 bx lr
 .type callee_high2,%function
callee_high2:
 bx lr

 .section .callee_arm_high, "ax",%progbits
 .arm
 .balign 0x100
 .type callee_arm_high,%function
callee_arm_high:
  bx lr

// CHECK-THUMB: Disassembly of section .callee1:
// CHECK-THUMB-NEXT: callee_low:
// CHECK-THUMB-NEXT:    b4:       70 47   bx      lr
// CHECK-THUMB: callee_low2:
// CHECK-THUMB-NEXT:    b6:       70 47   bx      lr

// CHECK-ARM: Disassembly of section .callee2:
// CHECK-ARM-NEXT: callee_arm_low:
// CHECK-ARM-NEXT:    100:        1e ff 2f e1     bx      lr

// CHECK-ARM: Disassembly of section .caller:
// CHECK-ARM-NEXT: _start:
// CHECK-ARM-NEXT:   10000:       2b c0 ff fa     blx     #-65364 <callee_low>
// CHECK-ARM-NEXT:   10004:       2a c0 ff fa     blx     #-65368 <callee_low>
// CHECK-ARM-NEXT:   10008:       29 c0 ff fb     blx     #-65370 <callee_low2>
// CHECK-ARM-NEXT:   1000c:       28 c0 ff fb     blx     #-65374 <callee_low2>
// CHECK-ARM-NEXT:   10010:       3a 00 00 fa     blx     #232 <callee_high>
// CHECK-ARM-NEXT:   10014:       39 00 00 fa     blx     #228 <callee_high>
// CHECK-ARM-NEXT:   10018:       38 00 00 fb     blx     #226 <callee_high2>
// CHECK-ARM-NEXT:   1001c:       37 00 00 fb     blx     #222 <callee_high2>
// 10020 + 1FFFFFC + 8 = 0x2010024 = blx_far
// CHECK-ARM-NEXT:   10020:       ff ff 7f fa     blx     #33554428
// 10024 + 1FFFFFC + 8 = 0x2010028 = blx_far2
// CHECK-ARM-NEXT:   10024:       ff ff 7f fa     blx     #33554428
// CHECK-ARM-NEXT:   10028:       34 c0 ff eb     bl      #-65328 <callee_arm_low>
// CHECK-ARM-NEXT:   1002c:       33 c0 ff eb     bl      #-65332 <callee_arm_low>
// CHECK-ARM-NEXT:   10030:       72 00 00 eb     bl      #456 <callee_arm_high>
// CHECK-ARM-NEXT:   10034:       71 00 00 eb     bl      #452 <callee_arm_high>
// CHECK-ARM-NEXT:   10038:       1e ff 2f e1     bx      lr

// CHECK-THUMB: Disassembly of section .callee3:
// CHECK-THUMB: callee_high:
// CHECK-THUMB-NEXT:    10100:       70 47   bx      lr
// CHECK-THUMB: callee_high2:
// CHECK-THUMB-NEXT:    10102:       70 47   bx      lr

// CHECK-ARM: Disassembly of section .callee4:
// CHECK-NEXT-ARM: callee_arm_high:
// CHECK-NEXT-ARM:   10200:     1e ff 2f e1     bx      lr
