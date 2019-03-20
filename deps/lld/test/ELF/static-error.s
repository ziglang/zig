// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/shared.s -o %t.o
// RUN: ld.lld -shared -o %t.so %t.o

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -o /dev/null %t.o %t.so
// RUN: not ld.lld -o /dev/null -static %t.o %t.so 2>&1 | FileCheck %s

// CHECK: attempted static link of dynamic object

.global _start
_start:
  nop
