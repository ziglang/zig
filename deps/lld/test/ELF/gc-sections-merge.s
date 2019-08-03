// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: ld.lld %t.o -o %t.gc.so -shared --gc-sections
// RUN: llvm-readobj -S --section-data %t.so | FileCheck %s
// RUN: llvm-readobj -S --section-data %t.gc.so | FileCheck --check-prefix=GC %s


// CHECK:      Name: .rodata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT:   SHF_STRINGS
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 8
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 1
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 666F6F00 62617200                    |foo.bar.|
// CHECK-NEXT: )

// GC:      Name: .rodata
// GC-NEXT: Type: SHT_PROGBITS
// GC-NEXT: Flags [
// GC-NEXT:   SHF_ALLOC
// GC-NEXT:   SHF_MERGE
// GC-NEXT:   SHF_STRINGS
// GC-NEXT: ]
// GC-NEXT: Address:
// GC-NEXT: Offset:
// GC-NEXT: Size: 4
// GC-NEXT: Link: 0
// GC-NEXT: Info: 0
// GC-NEXT: AddressAlignment: 1
// GC-NEXT: EntrySize: 1
// GC-NEXT: SectionData (
// GC-NEXT:   0000: 666F6F00                                |foo.|
// GC-NEXT: )

        .section        .text.f,"ax",@progbits
        .globl  f
f:
        leaq    .L.str(%rip), %rax
        retq

        .section        .text.g,"ax",@progbits
        .hidden g
        .globl  g
g:
        leaq    .L.str.1(%rip), %rax
        retq

        .section        .rodata.str1.1,"aMS",@progbits,1
.L.str:
        .asciz  "foo"
.L.str.1:
        .asciz  "bar"
