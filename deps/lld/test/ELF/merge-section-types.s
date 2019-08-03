// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t
// RUN: llvm-readobj -S %t | FileCheck %s

// CHECK:      Name: .foo
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2000
// CHECK-NEXT: Offset: 0x2000
// CHECK-NEXT: Size: 16

.section .foo, "aw", @progbits, unique, 1
.quad 0

.section .foo, "aw", @nobits, unique, 2
.quad 0
