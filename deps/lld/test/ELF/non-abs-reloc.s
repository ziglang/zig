// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o -o %t.so -shared 2>&1 | FileCheck %s
// CHECK: {{.*}}:(.dummy+0x0): has non-ABS reloc

.globl _start
_start:
  nop

.section .dummy
  .long foo@gotpcrel
