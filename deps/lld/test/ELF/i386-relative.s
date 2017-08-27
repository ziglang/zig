// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readobj -r %t.so | FileCheck %s

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rel.dyn {
// CHECK-NEXT:     R_386_RELATIVE - 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

        .data
foo:
        .long foo
