// RUN: llvm-mc -filetype=obj -triple=arm-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1 | FileCheck %s
// REQUIRES: arm

// On Arm v6 the range of a Thumb BL instruction is only 4 megabytes as the
// extended range encoding is not supported. The following example has a Thumb
// BL that is out of range on ARM v6 and requires a range extension thunk.
// As v6 does not support MOVT or MOVW instructions the Thunk must not
// use these instructions either. At present we don't support v6 so we give a
// warning for unsupported features.

// CHECK: warning: lld uses extended branch encoding, no object with architecture supporting feature detected.
// CHECK-NEXT: warning: lld may use movt/movw, no object with architecture supporting feature detected.
// ARM v6 supports blx so we shouldn't see the blx not supported warning.
// CHECK-NOT: warning: lld uses blx instruction, no object with architecture supporting feature detected.
 .text
 .syntax unified
 .cpu    arm1176jzf-s
 .eabi_attribute 6, 6    @ Tag_CPU_arch
 .globl _start
 .type   _start,%function
 .balign 0x1000
_start:
  bl thumbfunc
  bx lr

 .thumb
 .section .text.2, "ax", %progbits
 .globl thumbfunc
 .type thumbfunc,%function
thumbfunc:
 bl farthumbfunc

// 6 Megabytes, enough to make farthumbfunc out of range of caller on a v6
// Arm, but not on a v7 Arm.
 .section .text.3, "ax", %progbits
 .space 0x200000

 .section .text.4, "ax", %progbits
 .space 0x200000

 .section .text.5, "ax", %progbits
 .space 0x200000

 .thumb
 .section .text.6, "ax", %progbits
 .balign 0x1000
 .globl farthumbfunc
 .type farthumbfunc,%function
farthumbfunc:
 bx lr
