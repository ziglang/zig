// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-arm-abs.s -o %tfar
// RUN: ld.lld  %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck --check-prefix=SHORT %s
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-long-arm-abs.s -o %tfarlong
// RUN: ld.lld  %t %tfarlong -o %t3 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t3 | FileCheck --check-prefix=LONG %s
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

// SHORT: Disassembly of section .text:
// SHORT-NEXT: _start:
// SHORT-NEXT:    20000:       01 00 00 eb     bl      #4 <__ARMv7ABSLongThunk_too_far1>
// SHORT-NEXT:    20004:       01 00 00 ea     b       #4 <__ARMv7ABSLongThunk_too_far2>
// SHORT-NEXT:    20008:       01 00 00 0a     beq     #4 <__ARMv7ABSLongThunk_too_far3>
// SHORT: __ARMv7ABSLongThunk_too_far1:
// SHORT-NEXT:    2000c:       fd ff 7f ea     b       #33554420 <__ARMv7ABSLongThunk_too_far3+0x1fffff4>
// SHORT: __ARMv7ABSLongThunk_too_far2:
// SHORT-NEXT:    20010:       fd ff 7f ea     b       #33554420 <__ARMv7ABSLongThunk_too_far3+0x1fffff8>
// SHORT: __ARMv7ABSLongThunk_too_far3:
// SHORT-NEXT:    20014:       fd ff 7f ea     b       #33554420 <__ARMv7ABSLongThunk_too_far3+0x1fffffc>

// LONG: Disassembly of section .text:
// LONG-NEXT: _start:
// LONG-NEXT:    20000:       01 00 00 eb     bl      #4 <__ARMv7ABSLongThunk_too_far1>
// LONG-NEXT:    20004:       03 00 00 ea     b       #12 <__ARMv7ABSLongThunk_too_far2>
// LONG-NEXT:    20008:       05 00 00 0a     beq     #20 <__ARMv7ABSLongThunk_too_far3>
// LONG: __ARMv7ABSLongThunk_too_far1:
// LONG-NEXT:    2000c:       14 c0 00 e3     movw    r12, #20
// LONG-NEXT:    20010:       02 c2 40 e3     movt    r12, #514
// LONG-NEXT:    20014:       1c ff 2f e1     bx      r12
// LONG: __ARMv7ABSLongThunk_too_far2:
// LONG-NEXT:    20018:       20 c0 00 e3     movw    r12, #32
// LONG-NEXT:    2001c:       02 c2 40 e3     movt    r12, #514
// LONG-NEXT:    20020:       1c ff 2f e1     bx      r12
// LONG: __ARMv7ABSLongThunk_too_far3:
// LONG-NEXT:    20024:       2c c0 00 e3     movw    r12, #44
// LONG-NEXT:    20028:       02 c2 40 e3     movt    r12, #514
// LONG-NEXT:    2002c:       1c ff 2f e1     bx      r12
