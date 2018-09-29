// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -s -section-data -t %t.so | FileCheck %s

// CHECK:      Name: .bar
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 16
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 10020000 00000000 18020000 00000000  |
// CHECK-NEXT: )

// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x210

        .section        .foo,"aM",@progbits,4
        .align  4
        .global foo
        .hidden foo
foo:
        .long   0x42

        .section .bar
        .quad foo
        .quad foo + 8
