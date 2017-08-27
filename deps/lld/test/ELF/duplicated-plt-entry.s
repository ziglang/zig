// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/duplicated-plt-entry.s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t.so -o %t2.so -shared

// RUN: llvm-readobj -r %t2.so | FileCheck %s
// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:       R_X86_64_JUMP_SLOT bar 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

callq bar@PLT
callq bar@PLT
