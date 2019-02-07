// REQUIRES: arm
// RUN: llvm-mc %s -triple=armv7a-linux-gnueabihf -arm-add-build-attributes -filetype=obj -o %t.o
// RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

// CHECK: InputSection too large for range extension thunk
        .syntax unified
        .thumb
        .text
        .globl _start
        .type _start, %function
_start:
        .space 2 * 1024 * 1024
        // conditional branch has range of 1 Mb expect error as we can't place
        // a thunk in range of the branch.
        beq target
        .space 2 * 1024 * 1024

        .section .text.2, "ax", %progbits
        .globl target
        .type target, %function
target: bx lr
