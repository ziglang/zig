// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: llvm-mc %p/Inputs/shared.s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld %t.o %t2.so -o %t.exe
// RUN: llvm-readobj -t %t.exe | FileCheck %s

// CHECK:      Name: bar
// CHECK-NEXT: Value: 0x201020
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Weak
// CHECK-NEXT: Type: Function
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: Undefined

.global _start
_start:
        .weak bar
        .quad bar
