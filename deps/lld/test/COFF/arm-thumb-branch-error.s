// RUN: llvm-mc -filetype=obj -triple=thumbv7a-windows-gnu %s -o %t
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-windows-gnu %S/Inputs/far-arm-thumb-abs.s -o %tfar
// RUN: not lld-link -entry:_start -subsystem:console %t %tfar -out:%t2 2>&1 | FileCheck %s
// REQUIRES: arm
 .syntax unified
 .globl _start
_start:
 bl  too_far1

// CHECK: relocation out of range
