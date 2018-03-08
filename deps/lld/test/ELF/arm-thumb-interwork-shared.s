// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --shared -o %t.so
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t.so | FileCheck %s
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t.so | FileCheck %s -check-prefix=PLT
// REQUIRES: arm
 .syntax unified
 .global sym1
 .global elsewhere
 .weak weakref
sym1:
 b.w elsewhere
 b.w weakref

// Check that we generate a thunk for an undefined symbol called via a plt
// entry.

// CHECK: Disassembly of section .text:
// CHECK-NEXT: sym1:
// CHECK-NEXT: 1000: 00 f0 02 b8 b.w #4 <__ThumbV7PILongThunk_elsewhere>
// CHECK-NEXT: 1004: 00 f0 06 b8 b.w #12 <__ThumbV7PILongThunk_weakref>
// CHECK: __ThumbV7PILongThunk_elsewhere:
// CHECK-NEXT:     1008:       40 f2 2c 0c     movw    r12, #44
// CHECK-NEXT:     100c:       c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:     1010:       fc 44   add     r12, pc
// CHECK-NEXT:     1012:       60 47   bx      r12
// CHECK: __ThumbV7PILongThunk_weakref:
// CHECK-NEXT:     1014:       40 f2 30 0c     movw    r12, #48
// CHECK-NEXT:     1018:       c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:     101c:       fc 44   add     r12, pc
// CHECK-NEXT:     101e:       60 47   bx      r12

// PLT: Disassembly of section .plt:
// PLT-NEXT: $a:
// PLT-NEXT:     1020:  04 e0 2d e5     str     lr, [sp, #-4]!
// PLT-NEXT:     1024:  00 e6 8f e2     add     lr, pc, #0, #12
// PLT-NEXT:     1028:  00 ea 8e e2     add     lr, lr, #0, #20
// PLT-NEXT:     102c:  dc ff be e5     ldr     pc, [lr, #4060]!
// PLT: $d:
// PLT-NEXT:     1030:  d4 d4 d4 d4     .word   0xd4d4d4d4
// PLT-NEXT:     1034:  d4 d4 d4 d4     .word   0xd4d4d4d4
// PLT-NEXT:     1038:  d4 d4 d4 d4     .word   0xd4d4d4d4
// PLT-NEXT:     103c:  d4 d4 d4 d4     .word   0xd4d4d4d4
// PLT: $a:
// PLT-NEXT:     1040:  00 c6 8f e2     add     r12, pc, #0, #12
// PLT-NEXT:     1044:  00 ca 8c e2     add     r12, r12, #0, #20
// PLT-NEXT:     1048:  c4 ff bc e5     ldr     pc, [r12, #4036]!
// PLT: $d:
// PLT-NEXT:     104c:  d4 d4 d4 d4     .word   0xd4d4d4d4
// PLT: $a:
// PLT-NEXT:     1050:  00 c6 8f e2     add     r12, pc, #0, #12
// PLT-NEXT:     1054:  00 ca 8c e2     add     r12, r12, #0, #20
// PLT-NEXT:     1058:  b8 ff bc e5     ldr     pc, [r12, #4024]!
// PLT: $d:
// PLT-NEXT:     105c:  d4 d4 d4 d4     .word   0xd4d4d4d4

