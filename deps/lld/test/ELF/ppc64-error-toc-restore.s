// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: not ld.lld %t.o %t2.so -o %t 2>&1 | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: not ld.lld %t.o %t2.so -o %t 2>&1 | FileCheck %s

# Calling external function bar needs a nop
// CHECK: call lacks nop, can't restore toc
    .text
    .abiversion 2

.global _start
_start:
  bl foo
