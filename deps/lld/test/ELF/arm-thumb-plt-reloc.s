// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %p/Inputs/arm-plt-reloc.s -o %t1
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t2
// RUN: ld.lld %t1 %t2 -o %t
// RUN: llvm-objdump -triple=thumbv7a-none-linux-gnueabi -d %t | FileCheck %s
// RUN: ld.lld --hash-style=sysv -shared %t1 %t2 -o %t3
// RUN: llvm-objdump -triple=thumbv7a-none-linux-gnueabi -d %t3 | FileCheck -check-prefix=DSOTHUMB %s
// RUN: llvm-objdump -triple=armv7a-none-linux-gnueabi -d %t3 | FileCheck -check-prefix=DSOARM %s
// RUN: llvm-readobj -s -r %t3 | FileCheck -check-prefix=DSOREL %s
//
// Test PLT entry generation
 .syntax unified
 .text
 .align 2
 .globl _start
 .type  _start,%function
_start:
// FIXME, interworking is only supported for BL via BLX at the moment, when
// interworking thunks are available for b.w and b<cond>.w this can be altered
// to test the different forms of interworking.
 bl func1
 bl func2
 bl func3

// Executable, expect no PLT
// CHECK: Disassembly of section .text:
// CHECK-NEXT: func1:
// CHECK-NEXT:   11000: 70 47   bx      lr
// CHECK: func2:
// CHECK-NEXT:   11002: 70 47   bx      lr
// CHECK: func3:
// CHECK-NEXT:   11004: 70 47   bx      lr
// CHECK-NEXT:   11006: d4 d4
// CHECK: _start:
// 11008 + 4 -12 = 0x11000 = func1
// CHECK-NEXT:   11008: ff f7 fa ff     bl      #-12
// 1100c + 4 -14 = 0x11002 = func2
// CHECK-NEXT:   1100c: ff f7 f9 ff     bl      #-14
// 11010 + 4 -16 = 0x11004 = func3
// CHECK-NEXT:   11010: ff f7 f8 ff     bl      #-16

// Expect PLT entries as symbols can be preempted
// .text is Thumb and .plt is ARM, llvm-objdump can currently only disassemble
// as ARM or Thumb. Work around by disassembling twice.
// DSOTHUMB: Disassembly of section .text:
// DSOTHUMB-NEXT: func1:
// DSOTHUMB-NEXT:     1000:     70 47   bx      lr
// DSOTHUMB: func2:
// DSOTHUMB-NEXT:     1002:     70 47   bx      lr
// DSOTHUMB: func3:
// DSOTHUMB-NEXT:     1004:     70 47   bx      lr
// DSOTHUMB-NEXT:     1006:     d4 d4   bmi     #-88
// DSOTHUMB: _start:
// 0x1008 + 0x34 + 4 = 0x1040 = PLT func1
// DSOTHUMB-NEXT:     1008:     00 f0 1a e8     blx     #52
// 0x100c + 0x40 + 4 = 0x1050 = PLT func2
// DSOTHUMB-NEXT:     100c:     00 f0 20 e8     blx     #64
// 0x1010 + 0x4C + 4 = 0x1060 = PLT func3
// DSOTHUMB-NEXT:     1010:     00 f0 26 e8     blx     #76
// DSOARM: Disassembly of section .plt:
// DSOARM-NEXT: $a:
// DSOARM-NEXT:     1020:       04 e0 2d e5     str     lr, [sp, #-4]!
// (0x1024 + 8) + (0 RoR 12) + (0 RoR 20) + (0xfdc) = 0x2008 = .got.plt[3]
// DSOARM-NEXT:     1024:       00 e6 8f e2     add     lr, pc, #0, #12
// DSOARM-NEXT:     1028:       00 ea 8e e2     add     lr, lr, #0, #20
// DSOARM-NEXT:     102c:       dc ff be e5     ldr     pc, [lr, #4060]!
// DSOARM: $d:

// DSOARM-NEXT:     1030:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM-NEXT:     1034:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM-NEXT:     1038:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM-NEXT:     103c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM: $a:
// (0x1040 + 8) + (0 RoR 12) + (0 RoR 20) + (0xfc4) = 0x200c
// DSOARM-NEXT:     1040:       00 c6 8f e2     add     r12, pc, #0, #12
// DSOARM-NEXT:     1044:       00 ca 8c e2     add     r12, r12, #0, #20
// DSOARM-NEXT:     1048:       c4 ff bc e5     ldr     pc, [r12, #4036]!
// DSOARM: $d:
// DSOARM-NEXT:     104c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM: $a:
// (0x1050 + 8) + (0 RoR 12) + (0 RoR 20) + (0xfb8) = 0x2010
// DSOARM-NEXT:     1050:       00 c6 8f e2     add     r12, pc, #0, #12
// DSOARM-NEXT:     1054:       00 ca 8c e2     add     r12, r12, #0, #20
// DSOARM-NEXT:     1058:       b8 ff bc e5     ldr     pc, [r12, #4024]!
// DSOARM: $d:
// DSOARM-NEXT:     105c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DSOARM: $a:
// (0x1060 + 8) + (0 RoR 12) + (0 RoR 20) + (0xfac) = 0x2014
// DSOARM-NEXT:     1060:       00 c6 8f e2     add     r12, pc, #0, #12
// DSOARM-NEXT:     1064:       00 ca 8c e2     add     r12, r12, #0, #20
// DSOARM-NEXT:     1068:       ac ff bc e5     ldr     pc, [r12, #4012]!
// DSOARM: $d:
// DSOARM-NEXT:     106c:       d4 d4 d4 d4     .word   0xd4d4d4d4

// DSOREL:    Name: .got.plt
// DSOREL-NEXT:    Type: SHT_PROGBITS
// DSOREL-NEXT:    Flags [
// DSOREL-NEXT:      SHF_ALLOC
// DSOREL-NEXT:      SHF_WRITE
// DSOREL-NEXT:    ]
// DSOREL-NEXT:    Address: 0x2000
// DSOREL-NEXT:    Offset:
// DSOREL-NEXT:    Size: 24
// DSOREL-NEXT:    Link:
// DSOREL-NEXT:    Info:
// DSOREL-NEXT:    AddressAlignment: 4
// DSOREL-NEXT:    EntrySize:
// DSOREL:  Relocations [
// DSOREL-NEXT:  Section (4) .rel.plt {
// DSOREL-NEXT:    0x200C R_ARM_JUMP_SLOT func1 0x0
// DSOREL-NEXT:    0x2010 R_ARM_JUMP_SLOT func2 0x0
// DSOREL-NEXT:    0x2014 R_ARM_JUMP_SLOT func3 0x0
