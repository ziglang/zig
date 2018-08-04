// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %p/Inputs/i386-pic-plt.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: not ld.lld %t.o %t2.so -o %t -pie 2>&1 | FileCheck %s

// CHECK: error: symbol 'foo' cannot be preempted; recompile with -fPIE

.global _start
_start:
  call foo
