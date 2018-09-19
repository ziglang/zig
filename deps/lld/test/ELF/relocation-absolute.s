// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/abs.s -o %tabs
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %tabs %t -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s

.global _start
_start:
  movl $abs, %edx

//CHECK:      start:
//CHECK-NEXT: movl	$66, %edx
