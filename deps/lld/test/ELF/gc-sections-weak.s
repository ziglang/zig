// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/gc-sections-weak.s -o %t2.o
// RUN: ld.lld %t.o %t2.o -o %t.so -shared --gc-sections
// RUN: llvm-readobj -S %t.so | FileCheck %s

.global foo
foo:
nop

.data
.global bar1
bar1:
.quad foo

// CHECK:      Name: .text
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 1
