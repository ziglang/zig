// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       . = SIZEOF_HEADERS; \
// RUN:       .R_ARM_JUMP24_callee_1 : { *(.R_ARM_JUMP24_callee_low) } \
// RUN:       .R_ARM_THM_JUMP_callee_1 : { *(.R_ARM_THM_JUMP_callee_low)} \
// RUN:       .text : { *(.text) } \
// RUN:       .arm_caller : { *(.arm_caller) } \
// RUN:       .thumb_caller : { *(.thumb_caller) } \
// RUN:       .R_ARM_JUMP24_callee_2 : { *(.R_ARM_JUMP24_callee_high) } \
// RUN:       .R_ARM_THM_JUMP_callee_2 : { *(.R_ARM_THM_JUMP_callee_high) } \
// RUN:       .got.plt 0x18b4 : {  }  } " > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-THUMB -check-prefix=CHECK-ABS-THUMB %s
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-ARM -check-prefix=CHECK-ABS-ARM %s
// RUN: ld.lld --script %t.script %t -pie -o %t3 2>&1
// RUN: ld.lld --script %t.script %t --shared -o %t4 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t3 | FileCheck -check-prefix=CHECK-THUMB -check-prefix=CHECK-PI-THUMB %s
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t3 | FileCheck -check-prefix=CHECK-ARM -check-prefix=CHECK-PI-ARM %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t4 | FileCheck -check-prefix=CHECK-THUMB -check-prefix=CHECK-PI-PLT-THUMB %s
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t4 | FileCheck -check-prefix=CHECK-ARM -check-prefix=CHECK-PI-PLT-ARM %s
// RUN: llvm-readobj -S -r %t4 | FileCheck -check-prefix=CHECK-DSO-REL %s

// Test ARM Thumb Interworking
// The file is linked and checked 3 times to check the following contexts
// - Absolute executables, absolute Thunks are used.
// - Position independent executables, position independent Thunks are used.
// - Shared object, position independent Thunks to PLT entries are used.

 .syntax unified

// Target Sections for thunks at a lower address than the callers.
.section .R_ARM_JUMP24_callee_low, "ax", %progbits
 .thumb
 .balign 0x1000
 .globl thumb_callee1
 .type thumb_callee1, %function
thumb_callee1:
 bx lr

// CHECK-THUMB: Disassembly of section .R_ARM_JUMP24_callee_1:
// CHECK-THUMB-EMPTY:
// CHECK-THUMB: thumb_callee1:
// CHECK-THUMB: 1000:       70 47   bx
 .section .R_ARM_THM_JUMP_callee_low, "ax", %progbits
 .arm
 .balign 0x100
 .globl arm_callee1
 .type arm_callee1, %function
arm_callee1:
 bx lr
// Disassembly of section .R_ARM_THM_JUMP_callee_1:
// CHECK-ARM: arm_callee1:
// CHECK-ARM-NEXT: 1100:         1e ff 2f e1     bx      lr

 // Calling sections
 // At present ARM and Thumb interworking thunks are always added to the calling
 // section.
 .section .arm_caller, "ax", %progbits
 .arm
 .balign 0x100
 .globl arm_caller
 .type arm_caller, %function
arm_caller:
 // If target supports BLX and target is in range we don't need an
 // interworking thunk for a BL or BLX instruction.
 bl thumb_callee1
 blx thumb_callee1
 // A B instruction can't be transformed into a BLX and needs an interworking
 // thunk
 b thumb_callee1
 // As long as the thunk is in range it can be reused
 b thumb_callee1
 // There can be more than one thunk associated with a section
 b thumb_callee2
 b thumb_callee3
 // In range ARM targets do not require interworking thunks
 b arm_callee1
 beq arm_callee2
 bne arm_callee3
 bx lr
// CHECK-ARM-ABS-ARM: Disassembly of section .arm_caller:
// CHECK-ARM-ABS-ARM-EMPTY:
// CHECK-ARM-ABS-ARM-NEXT: arm_caller:
// CHECK-ARM-ABS-ARM-NEXT:     1300:       3e ff ff fa     blx     #-776 <thumb_callee1>
// CHECK-ARM-ABS-ARM-NEXT:     1304:       3d ff ff fa     blx     #-780 <thumb_callee1>
// CHECK-ARM-ABS-ARM-NEXT:     1308:       06 00 00 ea     b       #24 <__ARMv7ABSLongThunk_thumb_callee1>
// CHECK-ARM-ABS-ARM-NEXT:     130c:       05 00 00 ea     b       #20 <__ARMv7ABSLongThunk_thumb_callee1>
// CHECK-ARM-ABS-ARM-NEXT:     1310:       07 00 00 ea     b       #28 <__ARMv7ABSLongThunk_thumb_callee2>
// CHECK-ARM-ABS-ARM-NEXT:     1314:       09 00 00 ea     b       #36 <__ARMv7ABSLongThunk_thumb_callee3>
// CHECK-ARM-ABS-ARM-NEXT:     1318:       78 ff ff ea     b       #-544 <arm_callee1>
// CHECK-ARM-ABS-ARM-NEXT:     131c:       b7 00 00 0a     beq     #732 <arm_callee2>
// CHECK-ARM-ABS-ARM-NEXT:     1320:       b7 00 00 1a     bne     #732 <arm_callee3>
// CHECK-ARM-ABS-ARM-NEXT:     1324:       1e ff 2f e1     bx      lr
// CHECK-ARM-ABS-ARM: __ARMv7ABSLongThunk_thumb_callee1:
// 0x1001 = thumb_callee1
// CHECK-ARM-ABS-ARM-NEXT:     1328:       01 c0 01 e3     movw    r12, #4097
// CHECK-ARM-ABS-ARM-NEXT:     132c:       00 c0 40 e3     movt    r12, #0
// CHECK-ARM-ABS-ARM-NEXT:     1330:       1c ff 2f e1     bx      r12
// 0x1501 = thumb_callee2
// CHECK-ARM-ABS-ARM: __ARMv7ABSLongThunk_thumb_callee2:
// CHECK-ARM-ABS-ARM-NEXT:     1334:       01 c5 01 e3     movw    r12, #5377
// CHECK-ARM-ABS-ARM-NEXT:     1338:       00 c0 40 e3     movt    r12, #0
// CHECK-ARM-ABS-ARM-NEXT:     133c:       1c ff 2f e1     bx      r12
// 0x1503 = thumb_callee3
// CHECK-ARM-ABS-ARM: __ARMv7ABSLongThunk_thumb_callee3:
// CHECK-ARM-ABS-ARM-NEXT:     1340:       03 c5 01 e3     movw    r12, #5379
// CHECK-ARM-ABS-ARM-NEXT:     1344:       00 c0 40 e3     movt    r12, #0
// CHECK-ARM-ABS-ARM-NEXT:     1348:       1c ff 2f e1     bx      r12

// CHECK-PI-ARM: Disassembly of section .arm_caller:
// CHECK-PI-ARM-EMPTY:
// CHECK-PI-ARM-NEXT: arm_caller:
// CHECK-PI-ARM-NEXT:     1300:       3e ff ff fa     blx     #-776 <thumb_callee1>
// CHECK-PI-ARM-NEXT:     1304:       3d ff ff fa     blx     #-780 <thumb_callee1>
// CHECK-PI-ARM-NEXT:     1308:       06 00 00 ea     b       #24 <__ARMV7PILongThunk_thumb_callee1>
// CHECK-PI-ARM-NEXT:     130c:       05 00 00 ea     b       #20 <__ARMV7PILongThunk_thumb_callee1>
// CHECK-PI-ARM-NEXT:     1310:       08 00 00 ea     b       #32 <__ARMV7PILongThunk_thumb_callee2>
// CHECK-PI-ARM-NEXT:     1314:       0b 00 00 ea     b       #44 <__ARMV7PILongThunk_thumb_callee3>
// CHECK-PI-ARM-NEXT:     1318:       78 ff ff ea     b       #-544 <arm_callee1>
// CHECK-PI-ARM-NEXT:     131c:       b7 00 00 0a     beq     #732 <arm_callee2>
// CHECK-PI-ARM-NEXT:     1320:       b7 00 00 1a     bne     #732 <arm_callee3>
// CHECK-PI-ARM-NEXT:     1324:       1e ff 2f e1     bx      lr
// CHECK-PI-ARM: __ARMV7PILongThunk_thumb_callee1:
// 0x1330 + 8 - 0x337 = 0x1001 = thumb_callee1
// CHECK-PI-ARM-NEXT:     1328:       c9 cc 0f e3     movw    r12, #64713
// CHECK-PI-ARM-NEXT:     132c:       ff cf 4f e3     movt    r12, #65535
// CHECK-PI-ARM-NEXT:     1330:       0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-NEXT:     1334:       1c ff 2f e1     bx      r12
// CHECK-PI-ARM: __ARMV7PILongThunk_thumb_callee2:

// CHECK-PI-ARM-NEXT:     1338:       b9 c1 00 e3     movw    r12, #441
// CHECK-PI-ARM-NEXT:     133c:       00 c0 40 e3     movt    r12, #0
// CHECK-PI-ARM-NEXT:     1340:       0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-NEXT:     1344:       1c ff 2f e1     bx      r12
// CHECK-PI-ARM: __ARMV7PILongThunk_thumb_callee3:
// 0x1340 + 8 + 0x1b9 = 0x1501
// CHECK-PI-ARM-NEXT:     1348:       ab c1 00 e3     movw    r12, #427
// CHECK-PI-ARM-NEXT:     134c:       00 c0 40 e3     movt    r12, #0
// CHECK-PI-ARM-NEXT:     1350:       0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-NEXT:     1354:       1c ff 2f e1     bx      r12
// 1350 + 8 + 0x1ab = 0x1503

// All PLT entries are ARM, no need for interworking thunks
// CHECK-PI-ARM-PLT: Disassembly of section .arm_caller:
// CHECK-PI-ARM-PLT-EMPTY:
// CHECK-PI-ARM-PLT-NEXT: arm_caller:
// 0x17e4 PLT(thumb_callee1)
// CHECK-PI-ARM-PLT-NEXT:    1300:       37 01 00 eb     bl      #1244
// 0x17e4 PLT(thumb_callee1)
// CHECK-PI-ARM-PLT-NEXT:    1304:       36 01 00 eb     bl      #1240
// 0x17e4 PLT(thumb_callee1)
// CHECK-PI-ARM-PLT-NEXT:    1308:       35 01 00 ea     b       #1236
// 0x17e4 PLT(thumb_callee1)
// CHECK-PI-ARM-PLT-NEXT:    130c:       34 01 00 ea     b       #1232
// 0x17f4 PLT(thumb_callee2)
// CHECK-PI-ARM-PLT-NEXT:    1310:       37 01 00 ea     b       #1244
// 0x1804 PLT(thumb_callee3)
// CHECK-PI-ARM-PLT-NEXT:    1314:       3a 01 00 ea     b       #1256
// 0x1814 PLT(arm_callee1)
// CHECK-PI-ARM-PLT-NEXT:    1318:       3d 01 00 ea     b       #1268
// 0x1824 PLT(arm_callee2)
// CHECK-PI-ARM-PLT-NEXT:    131c:       40 01 00 0a     beq     #1280
// 0x1834 PLT(arm_callee3)
// CHECK-PI-ARM-PLT-NEXT:    1320:       43 01 00 1a     bne     #1292
// CHECK-PI-ARM-PLT-NEXT:    1324:       1e ff 2f e1     bx      lr

 .section .thumb_caller, "ax", %progbits
 .balign 0x100
 .thumb
 .globl thumb_caller
 .type thumb_caller, %function
thumb_caller:
 // If target supports BLX and target is in range we don't need an
 // interworking thunk for a BL or BLX instruction.
 bl arm_callee1
 blx arm_callee1
 // A B instruction can't be transformed into a BLX and needs an interworking
 // thunk
 b.w arm_callee1
 // As long as the thunk is in range it can be reused
 b.w arm_callee2
 // There can be more than one thunk associated with a section
 b.w arm_callee3
 // Conditional branches also require interworking thunks, they can use the
 // same interworking thunks.
 beq.w arm_callee1
 beq.w arm_callee2
 bne.w arm_callee3
// CHECK-ABS-THUMB: Disassembly of section .thumb_caller:
// CHECK-ABS-THUMB-EMPTY:
// CHECK-ABS-THUMB-NEXT: thumb_caller:
// CHECK-ABS-THUMB-NEXT:     1400:       ff f7 7e ee     blx     #-772
// CHECK-ABS-THUMB-NEXT:     1404:       ff f7 7c ee     blx     #-776
// CHECK-ABS-THUMB-NEXT:     1408:       00 f0 0a b8     b.w     #20 <__Thumbv7ABSLongThunk_arm_callee1>
// CHECK-ABS-THUMB-NEXT:     140c:       00 f0 0d b8     b.w     #26 <__Thumbv7ABSLongThunk_arm_callee2>
// CHECK-ABS-THUMB-NEXT:     1410:       00 f0 10 b8     b.w     #32 <__Thumbv7ABSLongThunk_arm_callee3>
// CHECK-ABS-THUMB-NEXT:     1414:       00 f0 04 80     beq.w   #8 <__Thumbv7ABSLongThunk_arm_callee1>
// CHECK-ABS-THUMB-NEXT:     1418:       00 f0 07 80     beq.w   #14 <__Thumbv7ABSLongThunk_arm_callee2>
// CHECK-ABS-THUMB-NEXT:     141c:       40 f0 0a 80     bne.w   #20 <__Thumbv7ABSLongThunk_arm_callee3>
// CHECK-ABS-THUMB: __Thumbv7ABSLongThunk_arm_callee1:
// 0x1100 = arm_callee1
// CHECK-ABS-THUMB-NEXT:     1420:       41 f2 00 1c     movw    r12, #4352
// CHECK-ABS-THUMB-NEXT:     1424:       c0 f2 00 0c     movt    r12, #0
// CHECK-ABS-THUMB-NEXT:     1428:       60 47   bx      r12
// CHECK-ABS-THUMB: __Thumbv7ABSLongThunk_arm_callee2:
// 0x1600 = arm_callee2
// CHECK-ABS-THUMB-NEXT:     142a:       41 f2 00 6c     movw    r12, #5632
// CHECK-ABS-THUMB-NEXT:     142e:       c0 f2 00 0c     movt    r12, #0
// CHECK-ABS-THUMB-NEXT:     1432:       60 47   bx      r12
// 0x1604 = arm_callee3
// CHECK-ABS-THUMB: __Thumbv7ABSLongThunk_arm_callee3:
// CHECK-ABS-THUMB-NEXT:     1434:   41 f2 04 6c     movw    r12, #5636
// CHECK-ABS-THUMB-NEXT:     1438:       c0 f2 00 0c     movt    r12, #0
// CHECK-ABS-THUMB-NEXT:     143c:       60 47   bx      r12

// CHECK-PI-THUMB: Disassembly of section .thumb_caller:
// CHECK-PI-THUMB-EMPTY:
// CHECK-PI-THUMB-NEXT: thumb_caller:
// CHECK-PI-THUMB-NEXT:     1400:       ff f7 7e ee     blx     #-772
// CHECK-PI-THUMB-NEXT:     1404:       ff f7 7c ee     blx     #-776
// CHECK-PI-THUMB-NEXT:     1408:       00 f0 0a b8     b.w     #20 <__ThumbV7PILongThunk_arm_callee1>
// CHECK-PI-THUMB-NEXT:     140c:       00 f0 0e b8     b.w     #28 <__ThumbV7PILongThunk_arm_callee2>
// CHECK-PI-THUMB-NEXT:     1410:       00 f0 12 b8     b.w     #36 <__ThumbV7PILongThunk_arm_callee3>
// CHECK-PI-THUMB-NEXT:     1414:       00 f0 04 80     beq.w   #8 <__ThumbV7PILongThunk_arm_callee1>
// CHECK-PI-THUMB-NEXT:     1418:       00 f0 08 80     beq.w   #16 <__ThumbV7PILongThunk_arm_callee2>
// CHECK-PI-THUMB-NEXT:     141c:       40 f0 0c 80     bne.w   #24 <__ThumbV7PILongThunk_arm_callee3>
// CHECK-PI-THUMB: __ThumbV7PILongThunk_arm_callee1:
// 0x1428 + 4 - 0x32c = 0x1100 = arm_callee1
// CHECK-PI-THUMB-NEXT:     1420:       4f f6 d4 4c     movw    r12, #64724
// CHECK-PI-THUMB-NEXT:     1424:       cf f6 ff 7c     movt    r12, #65535
// CHECK-PI-THUMB-NEXT:     1428:       fc 44   add     r12, pc
// CHECK-PI-THUMB-NEXT:     142a:       60 47   bx      r12
// CHECK-PI-THUMB: __ThumbV7PILongThunk_arm_callee2:
// 0x1434 + 4 + 0x1c8 = 0x1600 = arm_callee2
// CHECK-PI-THUMB-NEXT:     142c:       40 f2 c8 1c     movw    r12, #456
// CHECK-PI-THUMB-NEXT:     1430:       c0 f2 00 0c     movt    r12, #0
// CHECK-PI-THUMB-NEXT:     1434:       fc 44   add     r12, pc
// CHECK-PI-THUMB-NEXT:     1436:       60 47   bx      r12
// CHECK-PI-THUMB: __ThumbV7PILongThunk_arm_callee3:
// 0x1440 + 4 + 0x1c0 = 0x1604 = arm_callee3
// CHECK-PI-THUMB-NEXT:     1438:       40 f2 c0 1c     movw    r12, #448
// CHECK-PI-THUMB-NEXT:     143c:       c0 f2 00 0c     movt    r12, #0
// CHECK-PI-THUMB-NEXT:     1440:       fc 44   add     r12, pc
// CHECK-PI-THUMB-NEXT:     1442:       60 47   bx      r12

// CHECK-PI-THUMB-PLT: Disassembly of section .arm_caller:
// CHECK-PI-THUMB-PLT-EMPTY:
// CHECK-PI-THUMB-PLT-NEXT: thumb_caller:
// 0x1400 + 4 + 0x410 = 0x1814 = PLT(arm_callee1)
// CHECK-PI-THUMB-PLT-NEXT:    1400:    00 f0 08 ea     blx     #1040
// 0x1404 + 4 + 0x40c = 0x1814 = PLT(arm_callee1)
// CHECK-PI-THUMB-PLT-NEXT:    1404:    00 f0 06 ea     blx     #1036
// 0x1408 + 4 + 0x14 = 0x1420 = IWV(PLT(arm_callee1)
// CHECK-PI-THUMB-PLT-NEXT:    1408:    00 f0 0a b8     b.w     #20
// 0x140c + 4 + 0x1c = 0x142c = IWV(PLT(arm_callee2)
// CHECK-PI-THUMB-PLT-NEXT:    140c:    00 f0 0e b8     b.w     #28
// 0x1410 + 4 + 0x24 = 0x1438 = IWV(PLT(arm_callee3)
// CHECK-PI-THUMB-PLT-NEXT:    1410:    00 f0 12 b8     b.w     #36
// 0x1414 + 4 + 8 = 0x1420    = IWV(PLT(arm_callee1)
// CHECK-PI-THUMB-PLT-NEXT:    1414:    00 f0 04 80     beq.w   #8
// 0x1418 + 4 + 0x10 = 0x142c = IWV(PLT(arm_callee2)
// CHECK-PI-THUMB-PLT-NEXT:    1418:    00 f0 08 80     beq.w   #16
// 0x141c + 4 + 0x18 = 0x1438 = IWV(PLT(arm_callee3)
// CHECK-PI-THUMB-PLT-NEXT:    141c:    40 f0 0c 80     bne.w   #24
// 0x1428 + 4 + 0x3e8 = 0x1814 = PLT(arm_callee1)
// CHECK-PI-THUMB-PLT-NEXT:    1420:    40 f2 e8 3c     movw    r12, #1000
// CHECK-PI-THUMB-PLT-NEXT:    1424:    c0 f2 00 0c     movt    r12, #0
// CHECK-PI-THUMB-PLT-NEXT:    1428:    fc 44   add     r12, pc
// CHECK-PI-THUMB-PLT-NEXT:    142a:    60 47   bx      r12
// 0x1434 + 4 + 0x3ec = 0x1824 = PLT(arm_callee2)
// CHECK-PI-THUMB-PLT-NEXT:    142c:    40 f2 ec 3c     movw    r12, #1004
// CHECK-PI-THUMB-PLT-NEXT:    1430:    c0 f2 00 0c     movt    r12, #0
// CHECK-PI-THUMB-PLT-NEXT:    1434:    fc 44   add     r12, pc
// CHECK-PI-THUMB-PLT-NEXT:    1436:    60 47   bx      r12
// 0x1440 + 4 + 0x3f0 = 0x1834 = PLT(arm_callee3)
// CHECK-PI-THUMB-PLT-NEXT:    1438:    40 f2 f0 3c     movw    r12, #1008
// CHECK-PI-THUMB-PLT-NEXT:    143c:    c0 f2 00 0c     movt    r12, #0
// CHECK-PI-THUMB-PLT-NEXT:    1440:    fc 44   add     r12, pc
// CHECK-PI-THUMB-PLT-NEXT:    1442:    60 47   bx      r12

// Target Sections for thunks at a higher address than the callers.
.section .R_ARM_JUMP24_callee_high, "ax", %progbits
 .thumb
 .balign 0x100
 .globl thumb_callee2
 .type thumb_callee2, %function
thumb_callee2:
 bx lr

 .globl thumb_callee3
 .type thumb_callee3, %function
thumb_callee3:
 bx lr
// CHECK-THUMB:  Disassembly of section .R_ARM_JUMP24_callee_2:
// CHECK-THUMB-EMPTY:
// CHECK-THUMB-NEXT: thumb_callee2:
// CHECK-THUMB-NEXT: 1500:       70 47   bx      lr
// CHECK-THUMB: thumb_callee3:
// CHECK-THUMB-NEXT: 1502:       70 47   bx      lr

 .section .R_ARM_THM_JUMP_callee_high, "ax", %progbits
 .arm
 .balign 0x100
 .globl arm_callee2
 .type arm_callee2, %function
arm_callee2:
 bx lr
 .globl arm_callee3
 .type arm_callee3, %function
arm_callee3:
 bx lr
// CHECK-ARM: Disassembly of section .R_ARM_THM_JUMP_callee_2:
// CHECK-ARM-EMPTY:
// CHECK-ARM-NEXT: arm_callee2:
// CHECK-ARM-NEXT:     1600:     1e ff 2f e1     bx      lr
// CHECK-ARM: arm_callee3:
// CHECK-ARM-NEXT:     1604:     1e ff 2f e1     bx      lr

// _start section just calls the arm and thumb calling sections
 .text
 .arm
 .globl _start
 .balign 0x100
 .type _start, %function
_start:
 bl arm_caller
 bl thumb_caller
 bx lr


// CHECK-PI-ARM-PLT: Disassembly of section .plt:
// CHECK-PI-ARM-PLT-EMPTY:
// CHECK-PI-ARM-PLT-NEXT: .plt:
// CHECK-PI-ARM-PLT-NEXT: 17b0:         04 e0 2d e5     str     lr, [sp, #-4]!
// CHECK-PI-ARM-PLT-NEXT: 17b4:         04 e0 9f e5     ldr     lr, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 17b8:         0e e0 8f e0     add     lr, pc, lr
// CHECK-PI-ARM-PLT-NEXT: 17bc:         08 f0 be e5     ldr     pc, [lr, #8]!
// CHECK-PI-ARM-PLT-NEXT: 17c0:         d4 00 00 00
// 0x17c8 + 8 + 0xd0 = 0x18a0 arm_caller
// CHECK-PI-ARM-PLT-NEXT: 17c4:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 17c8:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 17cc:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 17d0:         d0 00 00 00
// 0x17d8 + 8 + 0xc4 = 0x18a4 thumb_caller
// CHECK-PI-ARM-PLT-NEXT: 17d4:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 17d8:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 17dc:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 17e0:         c4 00 00 00
// 0x17e8 + 8 + 0xb8 = 0x18a8 thumb_callee1
// CHECK-PI-ARM-PLT-NEXT: 17e4:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 17e8:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 17ec:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 17f0:         b8 00 00 00
// 0x17f8 + 8 + 0xac = 0x18ac thumb_callee2
// CHECK-PI-ARM-PLT-NEXT: 17f4:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 17f8:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 17fc:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 1800:         ac 00 00 00
// 0x1808 + 8 + 0xa0 = 0x18b0 thumb_callee3
// CHECK-PI-ARM-PLT-NEXT: 1804:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 1808:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 180c:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 1810:         a0 00 00 00
// 0x1818 + 8 + 0x94 = 0x18b4 arm_callee1
// CHECK-PI-ARM-PLT-NEXT: 1814:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 1818:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 181c:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 1820:         94 00 00 00
// 0x1828 + 8 + 0x88 = 0x18b8 arm_callee2
// CHECK-PI-ARM-PLT-NEXT: 1824:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 1828:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 182c:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 1830:         88 00 00 00
// 0x1838 + 8 + 0x7c = 0x18bc arm_callee3
// CHECK-PI-ARM-PLT-NEXT: 1834:         04 c0 9f e5     ldr     r12, [pc, #4]
// CHECK-PI-ARM-PLT-NEXT: 1838:         0f c0 8c e0     add     r12, r12, pc
// CHECK-PI-ARM-PLT-NEXT: 183c:         00 f0 9c e5     ldr     pc, [r12]
// CHECK-PI-ARM-PLT-NEXT: 1840:         7c 00 00 00

// CHECK-DSO-REL:      0x18C0 R_ARM_JUMP_SLOT arm_caller
// CHECK-DSO-REL-NEXT: 0x18C4 R_ARM_JUMP_SLOT thumb_caller
// CHECK-DSO-REL-NEXT: 0x18C8 R_ARM_JUMP_SLOT thumb_callee1
// CHECK-DSO-REL-NEXT: 0x18CC R_ARM_JUMP_SLOT thumb_callee2
// CHECK-DSO-REL-NEXT: 0x18D0 R_ARM_JUMP_SLOT thumb_callee3
// CHECK-DSO-REL-NEXT: 0x18D4 R_ARM_JUMP_SLOT arm_callee1
// CHECK-DSO-REL-NEXT: 0x18D8 R_ARM_JUMP_SLOT arm_callee2
// CHECK-DSO-REL-NEXT: 0x18DC R_ARM_JUMP_SLOT arm_callee3
