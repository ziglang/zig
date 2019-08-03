// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared -O3
// RUN: llvm-readobj -S --section-data %t.so | FileCheck %s

        .section        .rodata.4a,"aMS",@progbits,1
        .align 4
        .asciz "abcdef"

        .section        .rodata.4b,"aMS",@progbits,1
        .align 4
        .asciz "ef"

        .section        .rodata.4c,"aMS",@progbits,1
        .align 4
        .asciz "f"


// CHECK:      Name: .rodata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000:    61626364 65660000 6600               |abcdef..f.|
// CHECK-NEXT: )
