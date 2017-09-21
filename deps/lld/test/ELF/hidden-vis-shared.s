// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-readobj -r %t | FileCheck %s
// RUN: ld.lld %t2.so %t.o -o %t
// RUN: llvm-readobj -r %t | FileCheck %s

// CHECK:      Relocations [
// CHECK-NEXT: ]

.global _start
_start:
callq   bar
.hidden bar
.weak   bar
