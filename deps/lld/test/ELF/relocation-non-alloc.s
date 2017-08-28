// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %t -o %t2 -shared
// RUN: llvm-readobj -s -section-data -r %t2 | FileCheck %s

// CHECK:      Name: .data
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1000
// CHECK-NEXT: Offset: 0x1000
// CHECK-NEXT: Size: 16
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00000000 00000000 00000000 00000000
// CHECK-NEXT: )

// CHECK:      Name: foo
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT:    Flags [
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x0
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 32
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00100000 00000000 00100000 00000000
// CHECK-NEXT:   0010: 00100000 00000000 00100000 00000000
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.}}) .rela.dyn {
// CHECK-NEXT:     0x1000 R_X86_64_RELATIVE - 0x1000
// CHECK-NEXT:     0x1008 R_X86_64_64 zed 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

.data
        .global zed
zed:
bar:
        .quad bar
        .quad zed

        .section foo
        .quad bar
        .quad zed

        .section foo
        .quad bar
        .quad zed
