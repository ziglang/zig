// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readelf -l %t.so | FileCheck %s

// Test that we don't create an empty executable PT_LOAD.

// CHECK:      PHDR    {{.*}} R   0x8
// CHECK-NEXT: LOAD    {{.*}} R   0x1000
// CHECK-NEXT: LOAD    {{.*}} RW  0x1000
// CHECK-NEXT: DYNAMIC {{.*}} RW  0x8
