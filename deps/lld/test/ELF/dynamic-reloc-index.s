// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-readobj -r %t | FileCheck %s

// We used to record the wrong symbol index for this test

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:     0x203018 R_X86_64_JUMP_SLOT bar 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

        .global foobar
foobar:
        .global zedx
zedx:
        .global _start
_start:
.quad bar
