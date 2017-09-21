// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/abs-hidden.s -o %t2.o
// RUN: ld.lld %t.o %t2.o -o %t.so -shared
// RUN: llvm-readobj -r -s -section-data %t.so | FileCheck %s

        .quad foo
        .long foo@gotpcrel

// CHECK:      Name: .text
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1000
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 12
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 42000000 00000000 58100000
//                                       0x2060 - (0x1000 + 8) = 1058
// CHECK-NEXT: )

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2060
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 8
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 8
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 42000000 00000000
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT: ]
