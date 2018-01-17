// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-large.s -o %t1.o
// RUN: ld.lld -shared %t1.o -o %t1.so
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t1.so -o %t2
// RUN: llvm-readobj --dyn-symbols %t2 | FileCheck %s

        .global _start
_start:
        .quad foo

// CHECK:      Symbol {
// CHECK:        Name: foo
// CHECK-NEXT:   Value:
// CHECK-NEXT:   Size: 4294967297
// CHECK-NEXT:   Binding:
// CHECK-NEXT:   Type:
// CHECK-NEXT:   Other:
// CHECK-NEXT:   Section:         .bss.rel.ro
// CHECK-NEXT: }
