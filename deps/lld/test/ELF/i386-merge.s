// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t -shared
// RUN: llvm-readobj -s -section-data %t | FileCheck %s

// CHECK:      Name: .mysec
// CHECK-NEXT: Type:
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x158
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 42000000 |
// CHECK-NEXT: )


// CHECK:      Name: .data
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1000
// CHECK-NEXT: Offset: 0x1000
// CHECK-NEXT: Size: 4
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 58010000 |
// CHECK-NEXT: )

// The content of .data should be the address of .mysec.

        .data
        .long .mysec+4

        .section        .mysec,"aM",@progbits,4
        .align  4
        .long   0x42
        .long   0x42
