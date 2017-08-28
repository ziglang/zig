// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t -Map=- --gc-sections | FileCheck %s

.section .tbss,"awT",@nobits
// CHECK-NOT: foo
.globl foo
foo:
.align 8
.long 0
