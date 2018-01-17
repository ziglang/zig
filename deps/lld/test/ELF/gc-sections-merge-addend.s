// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t.so -shared --gc-sections
// RUN: llvm-readobj -s -section-data %t.so | FileCheck %s


// CHECK:      Name: .rodata
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
// CHECK-NEXT: EntrySize: 1
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 62617200                    |bar.|
// CHECK-NEXT: )

        .section        .data.f,"aw",@progbits
        .globl  f
f:
        .quad .rodata.str1.1 + 4

        .section        .data.g,"aw",@progbits
        .hidden g
        .globl  g
g:
        .quad .rodata.str1.1

        .section        .rodata.str1.1,"aMS",@progbits,1
.L.str:
        .asciz  "foo"
.L.str.1:
        .asciz  "bar"
