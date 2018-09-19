// REQUIRES:arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

// CHECK: arm-tag-vfp-args-illegal.s.tmp.o: unknown Tag_ABI_VFP_args value: 5
        .arch armv7-a
        .eabi_attribute 20, 1
        .eabi_attribute 21, 1
        .eabi_attribute 23, 3
        .eabi_attribute 24, 1
        .eabi_attribute 25, 1
        .eabi_attribute 26, 2
        .eabi_attribute 30, 6
        .eabi_attribute 34, 1
        .eabi_attribute 18, 4
        .eabi_attribute 28, 5 // Tag_ABI_VFP_args = 5 (Illegal value)

        .syntax unified
        .globl _start
        .type _start, %function
_start: bx lr
