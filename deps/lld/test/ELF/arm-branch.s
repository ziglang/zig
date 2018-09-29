// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/far-arm-abs.s -o %tfar
// RUN: echo "SECTIONS { \
// RUN:          . = 0xb4; \
// RUN:          .callee1 : { *(.callee_low) } \
// RUN:          .caller : { *(.text) } \
// RUN:          .callee2 : { *(.callee_high) } } " > %t.script
// RUN: ld.lld --script %t.script %t %tfar -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck  %s
 .syntax unified
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
 bl  far
 b   far
 bgt far
 bx lr

 .section .callee_high, "ax",%progbits
 .align 2
 .type callee_high,%function
callee_high:
 bx lr

// CHECK: Disassembly of section .caller:
// CHECK-NEXT: _start:
// S(callee_low) = 0xb4 P = 0x10000 A = -8 = -0xff54 = -65364
// CHECK-NEXT:   10000:       2b c0 ff eb          bl      #-65364 <callee_low>
// S(callee_low) = 0xb4 P = 0x10004 A = -8 = -0xff58 = -65368
// CHECK-NEXT:   10004:       2a c0 ff ea          b       #-65368 <callee_low>
// S(callee_low) = 0xb4 P = 0x10008 A = -8 = -0xff5c -65372
// CHECK-NEXT:   10008:       29 c0 ff 0a          beq     #-65372 <callee_low>
// S(callee_high) = 0x10028 P = 0x1000c A = -8 = 0x14 = 20
// CHECK-NEXT:   1000c:       05 00 00 eb          bl      #20 <callee_high>
// S(callee_high) = 0x10028 P = 0x10010 A = -8 = 0x10 = 16
// CHECK-NEXT:   10010:       04 00 00 ea          b       #16 <callee_high>
// S(callee_high) = 0x10028 P = 0x10014 A = -8 = 0x0c =12
// CHECK-NEXT:   10014:       03 00 00 1a          bne     #12 <callee_high>
// S(far) = 0x201001c P = 0x10018 A = -8 = 0x1fffffc = 33554428
// CHECK-NEXT:   10018:       ff ff 7f eb          bl      #33554428
// S(far) = 0x201001c P = 0x1001c A = -8 = 0x1fffff8 = 33554424
// CHECK-NEXT:   1001c:       fe ff 7f ea          b       #33554424
// S(far) = 0x201001c P = 0x10020 A = -8 = 0x1fffff4 = 33554420
// CHECK-NEXT:   10020:       fd ff 7f ca          bgt     #33554420
// CHECK-NEXT:   10024:       1e ff 2f e1          bx      lr
