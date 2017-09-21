// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %S/Inputs/far-arm-thumb-abs.s -o %tfar
// RUN: echo "SECTIONS { \
// RUN:          . = 0xb4; \
// RUN:          .callee1 : { *(.callee_low) } \
// RUN:          .caller : { *(.text) } \
// RUN:          .callee2 : { *(.callee_high) } } " > %t.script
// RUN: ld.lld --script %t.script %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck  %s
// REQUIRES: arm

 .syntax unified
 .thumb
 .section .callee_low, "ax",%progbits
 .align 2
 .type callee_low,%function
callee_low:
 bx lr

 .section .text, "ax",%progbits
 .globl _start
 .balign 0x10000
 .type _start,%function
_start:
 bl  callee_low
 b   callee_low
 beq callee_low
 bl  callee_high
 b   callee_high
 bne callee_high
 bl  far_uncond
 b   far_uncond
 bgt far_cond
 bx lr

 .section .callee_high, "ax",%progbits
 .align 2
 .type callee_high,%function
callee_high:
 bx lr

// CHECK: Disassembly of section .callee1:
// CHECK-NEXT: callee_low:
// CHECK-NEXT:      b4:       70 47   bx      lr
// CHECK-NEXT: Disassembly of section .caller:
// CHECK-NEXT: _start:
// CHECK-NEXT:   10000:       f0 f7 58 f8     bl      #-65360
// CHECK-NEXT:   10004:       f0 f7 56 b8     b.w     #-65364
// CHECK-NEXT:   10008:       30 f4 54 a8     beq.w   #-65368
// CHECK-NEXT:   1000c:       00 f0 0c f8     bl      #24
// CHECK-NEXT:   10010:       00 f0 0a b8     b.w     #20
// CHECK-NEXT:   10014:       40 f0 08 80     bne.w   #16
// CHECK-NEXT:   10018:       ff f3 ff d7     bl      #16777214
// CHECK-NEXT:   1001c:       ff f3 fd 97     b.w     #16777210
// CHECK-NEXT:   10020:       3f f3 ff af     bgt.w   #1048574
// CHECK-NEXT:   10024:       70 47   bx      lr
// CHECK-NEXT:   10026:
// CHECK-NEXT: Disassembly of section .callee2:
// CHECK-NEXT: callee_high:
// CHECK-NEXT:   10028:       70 47   bx      lr
