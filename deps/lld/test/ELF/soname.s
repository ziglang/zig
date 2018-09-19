// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -shared -soname=bar -o %t.so
// RUN: ld.lld %t.o -shared --soname=bar -o %t2.so
// RUN: ld.lld %t.o %t.so %t2.so -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s

// CHECK:  0x0000000000000001 NEEDED               Shared library: [bar]
// CHECK-NOT: NEEDED

.global _start
_start:
