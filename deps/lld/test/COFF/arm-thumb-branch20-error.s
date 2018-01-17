// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-windows-gnu %s -o %t.obj
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-windows-gnu %S/Inputs/far-arm-thumb-abs20.s -o %t.far.obj
// RUN: not lld-link -entry:_start -subsystem:console %t.obj %t.far.obj -out:%t.exe 2>&1 | FileCheck %s
 .syntax unified
 .globl _start
_start:
 bne too_far20

// CHECK: relocation out of range
