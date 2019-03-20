// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-windows-gnu %s -o %t.obj
// RUN: not lld-link -entry:_start -subsystem:console %t.obj -out:%t.exe 2>&1 | FileCheck %s
 .syntax unified
 .globl _start
_start:
 bne too_far20
 .space 0x100000
 .section .text$a, "xr"
too_far20:
 bx lr

// When trying to add a thunk at the end of the section, the thunk itself
// will be too far away, so this won't converge.

// CHECK: adding thunks hasn't converged
