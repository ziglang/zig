// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o

// Creates a R_AARCH64_ABS64 relocation against foo and bar
        .globl foo
foo:

        .global bar
        .hidden bar
bar:

        .data
        .xword foo
        .xword bar

// RUN: ld.lld -shared -o %t.so %t.o
// RUN: llvm-readobj -symbols -dyn-relocations %t.so | FileCheck %s

// CHECK:      Dynamic Relocations {
// CHECK-NEXT:   {{.*}} R_AARCH64_RELATIVE - [[BAR_ADDR:.*]]
// CHECK-NEXT:   {{.*}} R_AARCH64_ABS64 foo 0x0
// CHECK-NEXT: }

// CHECK:      Symbols [
// CHECK:        Symbol {
// CHECK:          Name: bar
// CHECK-NEXT:     Value: [[BAR_ADDR]]
