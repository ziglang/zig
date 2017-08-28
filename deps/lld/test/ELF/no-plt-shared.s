// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t.so -o %t2.so -shared
// RUN: llvm-readobj -r %t2.so | FileCheck %s

        .data
fp:
        .quad bar

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     R_X86_64_64 bar 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
