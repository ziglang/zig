// RUN: llvm-mc -filetype=obj -triple=armv7a-linux-gnueabihf %S/Inputs/arm-shared.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=armv7a-linux-gnueabihf %s -o %t.o
// RUN: ld.lld %t.so %t.o -o %tout
// RUN: llvm-objdump -triple=armv7a-linux-gnueabihf -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r -dynamic-table %tout | FileCheck %s
// REQUIRES: arm

// Check that the IRELATIVE relocations are last in the .got
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rel.dyn {
// CHECK-NEXT:     0x13078 R_ARM_GLOB_DAT bar2 0x0
// CHECK-NEXT:     0x1307C R_ARM_GLOB_DAT zed2 0x0
// CHECK-NEXT:     0x13080 R_ARM_IRELATIVE - 0x0
// CHECK-NEXT:     0x13084 R_ARM_IRELATIVE - 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Section (5) .rel.plt {
// CHECK-NEXT:     0x1200C R_ARM_JUMP_SLOT bar2 0x0
// CHECK-NEXT:     0x12010 R_ARM_JUMP_SLOT zed2 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// Check that the GOT entries refer back to the ifunc resolver
// GOTPLT: Contents of section .got.plt:
// GOTPLT-NEXT:  12000 00000000 00000000 00000000 20100100
// GOTPLT-NEXT:  12010 20100100
// GOTPLT: Contents of section .got:
// GOTPLT-NEXT:  13078 00000000 00000000 00100100 04100100

// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    11000:       1e ff 2f e1     bx      lr
// DISASM: bar:
// DISASM-NEXT:    11004:       1e ff 2f e1     bx      lr
// DISASM:      _start:
// DISASM-NEXT:    11008:       14 00 00 eb     bl      #80
// DISASM-NEXT:    1100c:       17 00 00 eb     bl      #92
// DISASM:         11010:       00 00 00 00     .word   0x00000000
// DISASM-NEXT:    11014:       04 00 00 00     .word   0x00000004
// DISASM:         11018:       05 00 00 eb     bl      #20
// DISASM-NEXT:    1101c:       08 00 00 eb     bl      #32
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: $a:
// DISASM-NEXT:    11020:       04 e0 2d e5     str     lr, [sp, #-4]!
// DISASM-NEXT:    11024:       04 e0 9f e5     ldr     lr, [pc, #4]
// DISASM-NEXT:    11028:       0e e0 8f e0     add     lr, pc, lr
// DISASM-NEXT:    1102c:       08 f0 be e5     ldr     pc, [lr, #8]!
// DISASM: $d:
// DISASM-NEXT:    11030:       d0 0f 00 00     .word   0x00000fd0
// DISASM: $a:
// DISASM-NEXT:    11034:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11038:       0f c0 8c e0     add     r12, r12, pc
// DISASM-NEXT:    1103c:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    11040:       cc 0f 00 00     .word   0x00000fcc
// DISASM: $a:
// DISASM-NEXT:    11044:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11048:       0f c0 8c e0     add     r12, r12, pc
// DISASM-NEXT:    1104c:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    11050:       c0 0f 00 00     .word   0x00000fc0
// Alignment to 16 byte boundary not strictly necessary on ARM, but harmless
// DISASM-NEXT:    11054:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DISASM-NEXT:    11058:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DISASM-NEXT:    1105c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// DISASM: $a:
// DISASM-NEXT:    11060:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11064:       0f c0 8c e0     add     r12, r12, pc
// DISASM-NEXT:    11068:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    1106c:       14 20 00 00     .word   0x00002014
// DISASM: $a:
// DISASM-NEXT:    11070:       04 c0 9f e5     ldr     r12, [pc, #4]
// DISASM-NEXT:    11074:       0f c0 8c e0     add     r12, r12, pc
// DISASM-NEXT:    11078:       00 f0 9c e5     ldr     pc, [r12]
// DISASM: $d:
// DISASM-NEXT:    1107c:       08 20 00 00     .word   0x00002008

.syntax unified
.text
.type foo STT_GNU_IFUNC
.globl foo
foo:
 bx lr

.type bar STT_GNU_IFUNC
.globl bar
bar:
 bx lr

.globl _start
_start:
 bl foo
 bl bar
 // Create entries in the .got and .rel.dyn so that we don't just have
 // IRELATIVE
 .word bar2(got)
 .word zed2(got)
 bl bar2
 bl zed2
