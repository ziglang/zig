// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %S/Inputs/arm-thumb-blx-targets.s -o %ttarget
// RUN: echo "SECTIONS { \
// RUN:          .R_ARM_CALL24_callee1 : { *(.R_ARM_CALL24_callee_low) } \
// RUN:          .R_ARM_CALL24_callee2 : { *(.R_ARM_CALL24_callee_thumb_low) } \
// RUN:          .caller : { *(.text) } \
// RUN:          .R_ARM_CALL24_callee3 : { *(.R_ARM_CALL24_callee_high) } \
// RUN:          .R_ARM_CALL24_callee4 : { *(.R_ARM_CALL24_callee_thumb_high) } } " > %t.script
// RUN: ld.lld --script %t.script %t %ttarget -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-THUMB %s
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-ARM %s
// REQUIRES: arm
// Test BLX instruction is chosen for Thumb BL/BLX instruction and ARM callee
// 2 byte nops are used to test the pc-rounding behaviour. As a BLX from a
// 2 byte aligned destination is defined as Align(PC,4) + immediate:00
// FIXME: llvm-mc has problems assembling BLX unless the destination is
// external. The targets of the BL and BLX instructions are in arm-thumb-blx-target.s
 .syntax unified
 .section .text, "ax",%progbits
 .thumb
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 blx  callee_low
 nop
 bl callee_low
 nop
 blx  callee_high
 nop
 bl callee_high
 nop
 blx  blx_far
 nop
 bl   blx_far
 nop
// Expect BLX to thumb target to be written out as a BL
 blx   callee_thumb_low
 nop
 blx   callee_thumb_high
 bx lr

// CHECK-ARM: Disassembly of section .R_ARM_CALL24_callee1:
// CHECK-NEXT-ARM: callee_low:
// CHECK-NEXT-ARM:      b4:     1e ff 2f e1     bx      lr

// CHECK-THUMB: Disassembly of section .R_ARM_CALL24_callee2:
// CHECK-NEXT-THUMB: callee_thumb_low:
// CHECK-NEXT-THUMB:     100:	70 47 	bx	lr

// CHECK-THUMB: Disassembly of section .caller:
// CHECK-THUMB: _start:
// Align(0x10000,4) - 0xff50 (65360) + 4 = 0xb4 = callee_low
// CHECK-NEXT-THUMB:   10000:       f0 f7 58 e8     blx     #-65360
// CHECK-NEXT-THUMB:   10004:       00 bf   nop
// Align(0x10006,4) - 0xff54 (65364) + 4 = 0xb4 = callee_low
// CHECK-NEXT-THUMB:   10006:       f0 f7 56 e8     blx     #-65364
// CHECK-NEXT-THUMB:   1000a:       00 bf   nop
// Align(0x1000c,4) + 0xf0 (240) + 4 = 0x10100 = callee_high
// CHECK-NEXT-THUMB:   1000c:   00 f0 78 e8     blx     #240
// CHECK-NEXT-THUMB:   10010:       00 bf   nop
// Align(0x10012,4) + 0xec (236) + 4 = 0x10100 = callee_high
// CHECK-NEXT-THUMB:   10012:       00 f0 76 e8     blx     #236
// CHECK-NEXT-THUMB:   10016:       00 bf   nop
// Align(0x10018,4) + 0xfffffc (16777212) = 0x1010018 = blx_far
// CHECK-NEXT-THUMB:   10018:       ff f3 fe c7     blx     #16777212
// CHECK-NEXT-THUMB:   1001c:       00 bf   nop
// Align(0x1001e,4) + 0xfffff8 (16777208) = 0x1010018 = blx_far
// CHECK-NEXT-THUMB:   1001e:       ff f3 fc c7     blx     #16777208
// CHECK-NEXT-THUMB:   10022:       00 bf   nop
// 10024 - 0xff28 (65320) + 4 = 0x100 = callee_thumb_low
// CHECK-NEXT-THUMB:   10024:       f0 f7 6c f8     bl      #-65320
// CHECK-NEXT-THUMB:   10028:       00 bf   nop
// 1002a + 0x1d2 (466) + 4 = 0x10200 = callee_thumb_high
// CHECK-NEXT-THUMB:   1002a:       00 f0 e9 f8     bl      #466
// CHECK-NEXT-THUMB:   1002e:       70 47   bx      lr


// CHECK-ARM: Disassembly of section .R_ARM_CALL24_callee3:
// CHECK-NEXT-ARM: callee_high:
// CHECK-NEXT-ARM:   10100:     1e ff 2f e1     bx      lr

// CHECK: Disassembly of section .R_ARM_CALL24_callee4:
// CHECK-NEXT-THUMB:callee_thumb_high:
// CHECK-NEXT-THUMB:   10200:   70 47   bx      lr
