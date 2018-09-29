// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t.so -shared -O3 --gc-sections
// RUN: llvm-readobj -s -section-data -t %t.so | FileCheck %s

// CHECK:      Name: .rodata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x235
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 4
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 1
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 61626300 |abc.|
// CHECK-NEXT: )

// CHECK:      Symbols [
// CHECK:        Symbol {
// CHECK-NOT:          Name: bar

        .global foo
foo:
        leaq    .L.str(%rip), %rsi
        .section        .rodata.str1.1,"aMS",@progbits,1
.L.str:
        .asciz  "abc"
bar:
        .asciz  "def"
