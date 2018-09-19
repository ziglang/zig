// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -shared -soname=foo.so -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s

// CHECK: 0x000000000000000E SONAME  Library soname: [foo.so]

.global _start
_start:
