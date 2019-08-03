// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -r -S --section-data %t.so | FileCheck %s

.data
.weak g
.hidden g
.quad g

// CHECK:      Name: .data
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 8
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00000000 00000000
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT: ]
