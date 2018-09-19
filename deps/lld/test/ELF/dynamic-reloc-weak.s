// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/dynamic-reloc-weak.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-readobj -r  %t | FileCheck %s

        .globl _start
_start:
        .type sym1,@function
        .weak sym1
        .long sym1@gotpcrel

        .type sym2,@function
        .weak sym2
        .long sym2@plt

        .type sym3,@function
        .weak sym3
        .quad sym3

        .type sym4,@function
        .weak sym4
        .quad sym4

// Test that we produce dynamic relocation for every weak undefined symbol
// we found.

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x{{.*}} R_X86_64_GLOB_DAT sym1 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:     0x{{.*}} R_X86_64_JUMP_SLOT sym2 0x0
// CHECK-NEXT:     0x{{.*}} R_X86_64_JUMP_SLOT sym3 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
