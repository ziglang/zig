// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-readobj --symbols %tout | FileCheck %s

// Check that no __rel_iplt_end/__rel_iplt_start
// appear in symtab if there are no references to them.
// CHECK:      Symbols [
// CHECK-NOT: __rel_iplt_end
// CHECK-NOT: __rel_iplt_start
// CHECK: ]
 .syntax unified
 .text
 .type foo STT_GNU_IFUNC
 .globl foo
foo:
 bx lr

 .type bar STT_GNU_IFUNC
 .globl bar
bar:
 bx lr

 .globl _start
_start:
 bl foo
 bl bar
