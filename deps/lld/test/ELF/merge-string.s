// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -O2 %t.o -o %t.so -shared
// RUN: llvm-readobj -s -section-data -t %t.so | FileCheck %s
// RUN: ld.lld -O1 %t.o -o %t.so -shared
// RUN: llvm-readobj -s -section-data -t %t.so | FileCheck --check-prefix=NOTAIL %s
// RUN: ld.lld -O0 %t.o -o %t.so -shared
// RUN: llvm-readobj -s -section-data -t %t.so | FileCheck --check-prefix=NOMERGE %s

        .section	.rodata1,"aMS",@progbits,1
	.asciz	"abc"
foo:
	.ascii	"a"
bar:
        .asciz  "bc"
        .asciz  "bc"

        .section        .rodata2,"aMS",@progbits,2
        .align  2
zed:
        .short  20
        .short  0

// CHECK:      Name:    .rodata1
// CHECK-NEXT: Type:    SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address:         0x1C8
// CHECK-NEXT: Offset:  0x1C8
// CHECK-NEXT: Size:    4
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 61626300                             |abc.|
// CHECK-NEXT: )

// NOTAIL:      Name:    .rodata1
// NOTAIL-NEXT: Type:    SHT_PROGBITS
// NOTAIL-NEXT: Flags [
// NOTAIL-NEXT:   SHF_ALLOC
// NOTAIL-NEXT:   SHF_MERGE
// NOTAIL-NEXT:   SHF_STRINGS
// NOTAIL-NEXT: ]
// NOTAIL-NEXT: Address:         0x1C8
// NOTAIL-NEXT: Offset:  0x1C8
// NOTAIL-NEXT: Size:    7
// NOTAIL-NEXT: Link: 0
// NOTAIL-NEXT: Info: 0
// NOTAIL-NEXT: AddressAlignment: 1
// NOTAIL-NEXT: EntrySize: 0
// NOTAIL-NEXT: SectionData (
// NOTAIL-NEXT:   0000: 61626300 626300                     |abc.bc.|
// NOTAIL-NEXT: )

// NOMERGE:      Name:    .rodata1
// NOMERGE-NEXT: Type:    SHT_PROGBITS
// NOMERGE-NEXT: Flags [
// NOMERGE-NEXT:   SHF_ALLOC
// NOMERGE-NEXT:   SHF_MERGE
// NOMERGE-NEXT:   SHF_STRINGS
// NOMERGE-NEXT: ]
// NOMERGE-NEXT: Address:         0x1C8
// NOMERGE-NEXT: Offset:  0x1C8
// NOMERGE-NEXT: Size:    11
// NOMERGE-NEXT: Link: 0
// NOMERGE-NEXT: Info: 0
// NOMERGE-NEXT: AddressAlignment: 1
// NOMERGE-NEXT: EntrySize: 1
// NOMERGE-NEXT: SectionData (
// NOMERGE-NEXT:   0000: 61626300 61626300 626300 |abc.abc.bc.|
// NOMERGE-NEXT: )

// CHECK:      Name: .rodata2
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1CC
// CHECK-NEXT: Offset: 0x1CC
// CHECK-NEXT: Size: 4
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 2
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 14000000                             |....|
// CHECK-NEXT: )


// CHECK:      Name:    bar
// CHECK-NEXT: Value:   0x1C9

// CHECK:      Name:    foo
// CHECK-NEXT: Value:   0x1C8

// CHECK:      Name: zed
// CHECK-NEXT: Value: 0x1CC
// CHECK-NEXT: Size: 0
