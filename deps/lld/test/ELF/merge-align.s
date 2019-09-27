// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -S --section-data %t.so | FileCheck %s

        .section        .rodata.foo,"aM",@progbits,1
        .align  16
        .byte 0x42

        .section        .rodata.bar,"aM",@progbits,1
        .align  16
        .byte 0x42

        .section        .rodata.zed,"aM",@progbits,1
        .align  16
        .byte 0x41

// CHECK:      Name: .rodata (
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 17
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 16
// CHECK-NEXT: EntrySize: 1
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 42000000 00000000 00000000 00000000  |
// CHECK-NEXT:   0010: 41                                   |
// CHECK-NEXT: )
