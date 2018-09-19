// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-version.s -o %t1.o
// RUN: echo "v1 {}; v2 {};" > %t.ver
// RUN: ld.lld %t1.o -shared -soname t1.so --version-script=%t.ver -o %t1.so
// RUN: ld.lld %t.o %t1.so -o %t
// RUN: llvm-readobj -t %t | FileCheck %s

.global _start
_start:
  leaq foo, %rax

// CHECK:      Name: foo (
// CHECK-NEXT: Value:
// CHECK-NEXT: Size: 8
