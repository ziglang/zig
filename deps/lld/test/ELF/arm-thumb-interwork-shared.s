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
// CHECK-NEXT:     1008:       40 f2 20 0c     movw    r12, #32
// CHECK-NEXT:     100c:       c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:     1010:       fc 44   add     r12, pc
// CHECK-NEXT:     1012:       60 47   bx      r12

// CHECK: __ThumbV7PILongThunk_weakref:
// CHECK-NEXT:     1014:       40 f2 24 0c     movw    r12, #36
// CHECK-NEXT:     1018:       c0 f2 00 0c     movt    r12, #0
// CHECK-NEXT:     101c:       fc 44   add     r12, pc
// CHECK-NEXT:     101e:       60 47   bx      r12

// PLT: Disassembly of section .plt:
// PLT: $a:
// PLT-NEXT:     1020:       04 e0 2d e5     str     lr, [sp, #-4]!
// PLT-NEXT:     1024:       04 e0 9f e5     ldr     lr, [pc, #4]
// PLT-NEXT:     1028:       0e e0 8f e0     add     lr, pc, lr
// PLT-NEXT:     102c:       08 f0 be e5     ldr     pc, [lr, #8]!
// PLT: $d:
// PLT-NEXT:     1030:       d0 0f 00 00     .word   0x00000fd0
// PLT: $a:
// PLT-NEXT:     1034:       04 c0 9f e5     ldr     r12, [pc, #4]
// PLT-NEXT:     1038:       0f c0 8c e0     add     r12, r12, pc
// PLT-NEXT:     103c:       00 f0 9c e5     ldr     pc, [r12]
// PLT: $d:
// PLT-NEXT:     1040:       cc 0f 00 00     .word   0x00000fcc
// PLT: $a:
// PLT-NEXT:     1044:       04 c0 9f e5     ldr     r12, [pc, #4]
// PLT-NEXT:     1048:       0f c0 8c e0     add     r12, r12, pc
// PLT-NEXT:     104c:       00 f0 9c e5     ldr     pc, [r12]
// PLT: $d:
// PLT-NEXT:     1050:       c0 0f 00 00     .word   0x00000fc0
