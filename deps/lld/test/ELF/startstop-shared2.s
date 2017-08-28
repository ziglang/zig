// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/startstop-shared2.s -o %t.o
// RUN: ld.lld -o %t.so %t.o -shared
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
// RUN: ld.lld -o %t %t2.o %t.so
// RUN: llvm-objdump -s -h %t | FileCheck %s

// CHECK: foo           00000000 0000000000201008

// CHECK: Contents of section .text:
// CHECK-NEXT: 201000 08102000 00000000

.quad __start_foo
.section foo,"ax"
