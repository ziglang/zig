// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %S/Inputs/far-arm-thumb-abs.s -o %tfar
// RUN: ld.lld  %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2
// REQUIRES: arm
 .syntax unified
 .thumb
 .section .text, "ax",%progbits
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 // address of too_far symbols are just out of range of ARM branch with
 // 26-bit immediate field and an addend of -8
 bl  too_far1
 b   too_far2
 beq.w too_far3

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:    20000:       00 f0 04 f8     bl      #8
// CHECK-NEXT:    20004:       00 f0 07 b8     b.w     #14 <__Thumbv7ABSLongThunk_too_far2>
// CHECK-NEXT:    20008:       00 f0 0a 80     beq.w   #20 <__Thumbv7ABSLongThunk_too_far3>
// CHECK: __Thumbv7ABSLongThunk_too_far1:
// CHECK-NEXT:    2000c:       40 f2 05 0c     movw    r12, #5
// CHECK-NEXT:    20010:       c0 f2 02 1c     movt    r12, #258
// CHECK-NEXT:    20014:       60 47   bx      r12
// CHECK: __Thumbv7ABSLongThunk_too_far2:
// CHECK-NEXT:    20016:       40 f2 09 0c     movw    r12, #9
// CHECK-NEXT:    2001a:       c0 f2 02 1c     movt    r12, #258
// CHECK-NEXT:    2001e:       60 47   bx      r12
// CHECK: __Thumbv7ABSLongThunk_too_far3:
// CHECK-NEXT:    20020:       40 f2 0d 0c     movw    r12, #13
// CHECK-NEXT:    20024:       c0 f2 12 0c     movt    r12, #18
// CHECK-NEXT:    20028:       60 47   bx      r12
// CHECK-NEXT:    2002a:       00 00   movs    r0, r0
