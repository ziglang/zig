// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld --hash-style=sysv %t --pie -o %t2
// RUN: llvm-readobj -r %t2 | FileCheck %s
// RUN: llvm-objdump -s %t2 | FileCheck %s --check-prefix=GOT

// Test that a R_ARM_GOT_BREL relocation with PIE results in a R_ARM_RELATIVE
// dynamic relocation
 .syntax unified
 .text
 .global _start
_start:
 .word sym(GOT)

 .data
 .global sym
sym:
 .word 0

// CHECK:      Relocations [
// CHECK-NEXT:   Section (4) .rel.dyn {
// CHECK-NEXT:     0x3058 R_ARM_RELATIVE

// GOT: Contents of section .got:
// GOT-NEXT:  3058 00200000
