// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv6-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:          .callee1 0x100004 : { *(.callee_low) } \
// RUN:          .caller  0x500000 : { *(.text) } \
// RUN:          .callee2 0x900004 : { *(.callee_high) } } " > %t.script
// RUN: ld.lld %t --script %t.script -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv6-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-THUMB %s
// RUN: llvm-objdump -d -triple=armv6-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-ARM %s

// On older Arm Architectures such as v5 and v6 the Thumb BL and BLX relocation
// uses a slightly different encoding that has a lower range. These relocations
// are at the extreme range of what is permitted.
 .thumb
 .text
 .syntax unified
 .cpu    arm1176jzf-s
 .globl _start
 .type   _start,%function
_start:
  bl thumbfunc
  bl armfunc
  bx lr

  .section .callee_low, "ax", %progbits
  .globl thumbfunc
  .type thumbfunc, %function
thumbfunc:
  bx lr
// CHECK-THUMB: Disassembly of section .callee1:
// CHECK-THUMB-NEXT: thumbfunc:
// CHECK-THUMB-NEXT:   100004:       70 47   bx      lr
// CHECK-THUMB-NEXT: Disassembly of section .caller:
// CHECK-THUMB-NEXT: _start:
// CHECK-THUMB-NEXT:   500000:       00 f4 00 f8     bl      #-4194304
// CHECK-THUMB-NEXT:   500004:       ff f3 fe ef     blx     #4194300
// CHECK-THUMB-NEXT:   500008:       70 47   bx      lr

  .arm
  .section .callee_high, "ax", %progbits
  .globl armfunc
  .type armfunc, %function
armfunc:
  bx lr
// CHECK-ARM: Disassembly of section .callee2:
// CHECK-ARM-NEXT: armfunc:
// CHECK-ARM-NEXT:   900004:       1e ff 2f e1     bx      lr
