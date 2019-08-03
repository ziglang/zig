// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -S -r --symbols %t | FileCheck %s
// RUN: llvm-objdump -triple=armv7a-linux-gnueabi -d %t | FileCheck --check-prefix=DISASM %s

// Test the R_ARM_GOTOFF32 relocation

// CHECK:      Name: .got
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [
// CHECK-NEXT:      SHF_ALLOC
// CHECK-NEXT:      SHF_WRITE
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x12000
// CHECK-NEXT:    Offset: 0x2000
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Link:
// CHECK-NEXT:    Info:
// CHECK-NEXT:    AddressAlignment:

// CHECK:    Name: .bss
// CHECK-NEXT:    Type: SHT_NOBITS
// CHECK-NEXT:    Flags [
// CHECK-NEXT:      SHF_ALLOC
// CHECK-NEXT:      SHF_WRITE
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x12000
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 20
// CHECK-NEXT:    Link:
// CHECK-NEXT:    Info:
// CHECK-NEXT:    AddressAlignment: 1

// CHECK-NEXT:    EntrySize: 0

// CHECK:       Symbol {
// CHECK:       Name: bar
// CHECK-NEXT:    Value: 0x12000
// CHECK-NEXT:    Size: 10
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: Object
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .bss
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: obj
// CHECK-NEXT:    Value: 0x1200A
// CHECK-NEXT:    Size: 10
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: Object
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .bss

// DISASM:      Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT :_start:
// DISASM-NEXT   11000:       1e ff 2f e1     bx      lr
// Offset 0 from .got = bar
// DISASM        11004:       00 00 00 00
// Offset 10 from .got = obj
// DISASM-NEXT   11008:       0a 00 00 00
// Offset 15 from .got = obj +5
// DISASM-NEXT   1100c:       0f 00 00 00
 .syntax unified
 .globl _start
_start:
 bx lr
 .word bar(GOTOFF)
 .word obj(GOTOFF)
 .word obj(GOTOFF)+5
 .type bar, %object
 .comm bar, 10
 .type obj, %object
 .comm obj, 10
