// REQUIRES: x86
// RUN: llvm-mc -filetype=obj %s -o %t.o -triple=x86_64-pc-linux
// RUN: ld.lld %t.o %t.o -r -o %t2.o
// RUN: llvm-readobj -r %t2.o | FileCheck %s

.weak foo
foo:
.quad foo

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.text {
// CHECK-NEXT:     0x0 R_X86_64_64 foo 0x0
// CHECK-NEXT:     0x8 R_X86_64_64 foo 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
