// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS {" > %t.script
// RUN: echo "          .text_low 0x130 : { *(.text) }" >> %t.script
// RUN: echo "          .text_high 0xf0000000 : AT(0x1000) { *(.text_high) }" >> %t.script
// RUN: echo "       } " >> %t.script
// RUN: ld.lld --script %t.script --pie --static %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s

// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t3
// RUN: ld.lld --script %t.script --pie %t3 -o %t4 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t4 | FileCheck -check-prefix=CHECK-THUMB %s

// Check that we can create Arm and Thumb v7a Position Independent Thunks that
// can span the address space without triggering overflow errors. We use an
// AT(0x1000) for .text_high to avoid creating an almost 4Gb size file.
 .syntax unified
 .text
 .global _start
 .type _start, %function
_start:
 bl high
 bx lr

 .section .text_high, "ax", %progbits
 .global high
 .type high, %function
high:
 bl _start
 bx lr

// ARMv7a instructions and relocations.

// CHECK: Disassembly of section .text_low:
// CHECK-NEXT: _start:
// CHECK-NEXT:      130:        00 00 00 eb     bl      #0 <__ARMV7PILongThunk_high>
// CHECK-NEXT:      134:        1e ff 2f e1     bx      lr

// CHECK: __ARMV7PILongThunk_high:
// CHECK-NEXT:      138:        b8 ce 0f e3     movw    r12, #65208
// CHECK-NEXT:      13c:        ff cf 4e e3     movt    r12, #61439
// 0x140 + 0xEFFF0000 + 0x0000FEB8 + 8 = 0xf0000000 = high
// CHECK-NEXT:      140:        0f c0 8c e0     add     r12, r12, pc
// CHECK-NEXT:      144:        1c ff 2f e1     bx      r12

// CHECK: Disassembly of section .text_high:
// CHECK-NEXT: high:
// CHECK-NEXT: f0000000:        00 00 00 eb     bl      #0 <__ARMV7PILongThunk__start>
// CHECK-NEXT: f0000004:        1e ff 2f e1     bx      lr

// CHECK: __ARMV7PILongThunk__start:
// CHECK-NEXT: f0000008:        18 c1 00 e3     movw    r12, #280
// CHECK-NEXT: f000000c:        00 c0 41 e3     movt    r12, #4096
// 0xf0000010 + 0x10000000 + 0x0000118 + 8 = bits32(0x100000130),0x130 = _start
// CHECK-NEXT: f0000010:        0f c0 8c e0     add     r12, r12, pc
// CHECK-NEXT: f0000014:        1c ff 2f e1     bx      r12

// Thumbv7a instructions and relocations
// CHECK-THUMB: Disassembly of section .text_low:
// CHECK-THUMB-NEXT: _start:
// CHECK-THUMB-NEXT:      130:  00 f0 02 f8     bl      #4
// CHECK-THUMB-NEXT:      134:  70 47   bx      lr
// CHECK-THUMB-NEXT:      136:  d4 d4   bmi     #-88

// CHECK-THUMB: __ThumbV7PILongThunk_high:
// CHECK-THUMB-NEXT:      138:  4f f6 bd 6c     movw    r12, #65213
// CHECK-THUMB-NEXT:      13c:  ce f6 ff 7c     movt    r12, #61439
// 0x140 + 0xEFFF0000 + 0x0000FEBD + 4 = 0xf0000001 = high
// CHECK-THUMB-NEXT:      140:  fc 44   add     r12, pc
// CHECK-THUMB-NEXT:      142:  60 47   bx      r12

// CHECK-THUMB: Disassembly of section .text_high:
// CHECK-THUMB-NEXT: high:
// CHECK-THUMB-NEXT: f0000000:  00 f0 02 f8     bl      #4
// CHECK-THUMB-NEXT: f0000004:  70 47   bx      lr

// CHECK-THUMB: __ThumbV7PILongThunk__start:
// CHECK-THUMB-NEXT: f0000008:  40 f2 1d 1c     movw    r12, #285
// CHECK-THUMB-NEXT: f000000c:  c1 f2 00 0c     movt    r12, #4096
// 0xf0000010 + 0x10000000 + 0x000011d +4 = bits32(0x100000131),0x131 = _start
// CHECK-THUMB-NEXT: f0000010:  fc 44   add     r12, pc
// CHECK-THUMB-NEXT: f0000012:  60 47   bx      r12
