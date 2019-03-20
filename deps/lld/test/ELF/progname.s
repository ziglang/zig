// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: echo ".global __progname; .data; .dc.a __progname" > %t2.s
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t2.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -o %t %t.o %t2.so
// RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

// RUN: echo "VER_1 { global: bar; };" > %t.script
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux \
// RUN:   %p/Inputs/progname-ver.s -o %t-ver.o
// RUN: ld.lld -shared -o %t.so -version-script %t.script %t-ver.o
// RUN: ld.lld -o %t %t.o %t.so
// RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

// RUN: echo "{ _start; };" > %t.dynlist
// RUN: ld.lld -dynamic-list %t.dynlist -o %t %t.o %t.so
// RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

// CHECK:      Name:     __progname
// CHECK-NEXT: Value:    0x201000
// CHECK-NEXT: Size:     0
// CHECK-NEXT: Binding:  Global (0x1)
// CHECK-NEXT: Type:     None (0x0)
// CHECK-NEXT: Other:    0
// CHECK-NEXT: Section:  .text
// CHECK-NEXT: }

.global _start, __progname
_start:
__progname:
  nop
