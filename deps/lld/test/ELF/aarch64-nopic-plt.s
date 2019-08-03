// REQUIRES: aarch64
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=aarch64-pc-linux
// RUN: llvm-mc %p/Inputs/aarch64-copy2.s -o %t2.o -filetype=obj -triple=aarch64-pc-linux
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-readobj --symbols %t | FileCheck %s

        .global _start
_start:
        adrp    x8, foo
        bl bar

// CHECK:      Name: bar
// CHECK-NEXT: Value: 0x0
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: None
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: Undefined

// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x210030
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: Function
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: Undefined
