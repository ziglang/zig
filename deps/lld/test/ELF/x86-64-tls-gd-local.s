// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -r -s -section-data %t.so | FileCheck %s

        .byte   0x66
        leaq    foo@tlsgd(%rip), %rdi
        .value  0x6666
        rex64
        call    __tls_get_addr@PLT

        .byte   0x66
        leaq    bar@tlsgd(%rip), %rdi
        .value  0x6666
        rex64
        call    __tls_get_addr@PLT

        .section        .tbss,"awT",@nobits

        .hidden foo
        .globl  foo
foo:
        .zero   4

        .hidden bar
        .globl  bar
bar:
        .zero   4


// CHECK:      Name: .got (
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC (0x2)
// CHECK-NEXT:   SHF_WRITE (0x1)
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x30D0
// CHECK-NEXT: Offset: 0x30D0
// CHECK-NEXT: Size: 32
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 8
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:   0010: 00000000 00000000 04000000 00000000  |................|
// CHECK-NEXT: )

// CHECK:      Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:   0x30D0 R_X86_64_DTPMOD64 - 0x0
// CHECK-NEXT:   0x30E0 R_X86_64_DTPMOD64 - 0x0
// CHECK-NEXT: }
