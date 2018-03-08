// RUN: llvm-mc -filetype=obj -triple=arm-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1 | FileCheck %s
// REQUIRES: arm

// On Arm v4t there is no blx instruction so all interworking must go via
// a thunk. At present we don't support v4t so we give a warning for unsupported
// features.

// CHECK: warning: lld uses blx instruction, no object with architecture supporting feature detected.
// CHECK-NEXT: warning: lld uses extended branch encoding, no object with architecture supporting feature detected.
// CHECK-NEXT: warning: lld may use movt/movw, no object with architecture supporting feature detected.

 .text
 .syntax unified
 .cpu   arm7tdmi
 .eabi_attribute        6, 2    @ Tag_CPU_arch
 .arm
 .globl _start
 .type   _start,%function
 .p2align       2
_start:
  bl thumbfunc
  bx lr

 .thumb
 .section .text.2, "ax", %progbits
 .globl thumbfunc
 .type thumbfunc,%function
thumbfunc:
 bx lr
