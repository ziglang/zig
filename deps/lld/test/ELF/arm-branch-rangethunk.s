// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-arm-abs.s -o %tfar
// RUN: ld.lld  %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .section .text, "ax",%progbits
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 // address of too_far symbols are just out of range of ARM branch with
 // 26-bit immediate field and an addend of -8
 bl  too_far1
 b   too_far2
 beq too_far3

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:    20000:       01 00 00 eb     bl      #4 <__ARMv7ABSLongThunk_too_far1>
// CHECK-NEXT:    20004:       03 00 00 ea     b       #12 <__ARMv7ABSLongThunk_too_far2>
// CHECK-NEXT:    20008:       05 00 00 0a     beq     #20 <__ARMv7ABSLongThunk_too_far3>
// CHECK: __ARMv7ABSLongThunk_too_far1:
// CHECK-NEXT:    2000c:       08 c0 00 e3     movw    r12, #8
// CHECK-NEXT:    20010:       02 c2 40 e3     movt    r12, #514
// CHECK-NEXT:    20014:       1c ff 2f e1     bx      r12
// CHECK: __ARMv7ABSLongThunk_too_far2:
// CHECK-NEXT:    20018:       0c c0 00 e3     movw    r12, #12
// CHECK-NEXT:    2001c:       02 c2 40 e3     movt    r12, #514
// CHECK-NEXT:    20020:       1c ff 2f e1     bx      r12
// CHECK: __ARMv7ABSLongThunk_too_far3:
// CHECK-NEXT:    20024:       10 c0 00 e3     movw    r12, #16
// CHECK-NEXT:    20028:       02 c2 40 e3     movt    r12, #514
// CHECK-NEXT:    2002c:       1c ff 2f e1     bx      r12
