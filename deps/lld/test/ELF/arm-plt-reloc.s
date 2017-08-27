// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-plt-reloc.s -o %t1
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t2
// RUN: ld.lld %t1 %t2 -o %t
// RUN: llvm-objdump -triple=armv7a-none-linux-gnueabi -d %t | FileCheck %s
// RUN: ld.lld -shared %t1 %t2 -o %t3
// RUN: llvm-objdump -triple=armv7a-none-linux-gnueabi -d %t3 | FileCheck -check-prefix=DSO %s
// RUN: llvm-readobj -s -r %t3 | FileCheck -check-prefix=DSOREL %s
// REQUIRES: arm
//
// Test PLT entry generation
 .syntax unified
 .text
 .align 2
 .globl _start
 .type  _start,%function
_start:
 b func1
 bl func2
 beq func3

// Executable, expect no PLT
// CHECK: Disassembly of section .text:
// CHECK-NEXT: func1:
// CHECK-NEXT:   11000:        1e ff 2f e1    bx      lr
// CHECK: func2:
// CHECK-NEXT:   11004:        1e ff 2f e1    bx      lr
// CHECK: func3:
// CHECK-NEXT:   11008:        1e ff 2f e1    bx      lr
// CHECK: _start:
// CHECK-NEXT:   1100c:        fb ff ff ea    b       #-20 <func1>
// CHECK-NEXT:   11010:        fb ff ff eb    bl      #-20 <func2>
// CHECK-NEXT:   11014:        fb ff ff 0a    beq     #-20 <func3>

// Expect PLT entries as symbols can be preempted
// DSO: Disassembly of section .text:
// DSO-NEXT: func1:
// DSO-NEXT:    1000:        1e ff 2f e1    bx      lr
// DSO: func2:
// DSO-NEXT:    1004:        1e ff 2f e1    bx      lr
// DSO: func3:
// DSO-NEXT:    1008:        1e ff 2f e1    bx      lr
// DSO: _start:
// S(0x1034) - P(0x100c) + A(-8) = 0x20 = 32
// DSO-NEXT:    100c:        08 00 00 ea    b       #32
// S(0x1044) - P(0x1010) + A(-8) = 0x2c = 44
// DSO-NEXT:    1010:        0b 00 00 eb    bl      #44
// S(0x1054) - P(0x1014) + A(-8) = 0x38 = 56
// DSO-NEXT:    1014:        0e 00 00 0a    beq     #56

// DSO: Disassembly of section .plt:
// DSO-NEXT: $a:
// DSO-NEXT:     1020:       04 e0 2d e5     str     lr, [sp, #-4]!
// DSO-NEXT:     1024:       04 e0 9f e5     ldr     lr, [pc, #4]
// DSO-NEXT:     1028:       0e e0 8f e0     add     lr, pc, lr
// DSO-NEXT:     102c:       08 f0 be e5     ldr     pc, [lr, #8]!
// 0x1028 + 8 + 0fd0 = 0x2000
// DSO: $d:
// DSO-NEXT:     1030:       d0 0f 00 00     .word   0x00000fd0
// DSO: $a:
// DSO-NEXT:     1034:       04 c0 9f e5     ldr     r12, [pc, #4]
// DSO-NEXT:     1038:       0f c0 8c e0     add     r12, r12, pc
// DSO-NEXT:     103c:       00 f0 9c e5     ldr     pc, [r12]
// 0x1038 + 8 + 0fcc = 0x200c        
// DSO: $d:
// DSO-NEXT:     1040:       cc 0f 00 00     .word   0x00000fcc
// DSO: $a:
// DSO-NEXT:     1044:       04 c0 9f e5     ldr     r12, [pc, #4]
// DSO-NEXT:     1048:       0f c0 8c e0     add     r12, r12, pc
// DSO-NEXT:     104c:       00 f0 9c e5     ldr     pc, [r12]
// 0x1048 + 8 + 0fc0 = 0x2010
// DSO: $d:
// DSO-NEXT:     1050:       c0 0f 00 00     .word   0x00000fc0
// DSO: $a:
// DSO-NEXT:     1054:       04 c0 9f e5     ldr     r12, [pc, #4]
// DSO-NEXT:     1058:       0f c0 8c e0     add     r12, r12, pc
// DSO-NEXT:     105c:       00 f0 9c e5     ldr     pc, [r12]
// 0x1058 + 8 + 0fb4 = 0x2014
// DSO: $d:
// DSO-NEXT:     1060:       b4 0f 00 00     .word   0x00000fb4

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
