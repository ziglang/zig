// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -s -section-data %t.so | FileCheck %s

        .section        .rodata.foo,"aMS",@progbits,1
        .align  16
        .asciz "foo"

        .section        .rodata.foo2,"aMS",@progbits,1
        .align  16
        .asciz "foo"

        .section        .rodata.bar,"aMS",@progbits,1
        .align  16
        .asciz "bar"

// CHECK:      Name: .rodata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 20
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 16
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000:  666F6F00 00000000 00000000 00000000  |foo.............|
// CHECK-NEXT:   0010:  62617200                             |bar.|
// CHECK-NEXT: )

        .section        .rodata2,"aMS",@progbits,1
        .asciz "foo"

// CHECK:      Name: .rodata2
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 4
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000:  666F6F00 |foo.|
// CHECK-NEXT: )
