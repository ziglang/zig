// REQUIRES:arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-base.s -o %tbase.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-vfp.s -o %tvfp.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-vfp-arg-toolchain.s -o %ttoolchain.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: not ld.lld %t.o %tbase.o %tvfp.o -o%t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o %tbase.o %ttoolchain.o -o%t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o %tvfp.o %tbase.o -o%t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o %tvfp.o %ttoolchain.o -o%t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o %ttoolchain.o %tbase.o -o%t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o %ttoolchain.o %tvfp.o -o%t 2>&1 | FileCheck %s

// CHECK: incompatible Tag_ABI_VFP_args
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
        .eabi_attribute 28, 3 // Tag_ABI_VFP_args = 3 (Compatible with all)

        .syntax unified
        .globl _start
        .type _start, %function
_start: bx lr
