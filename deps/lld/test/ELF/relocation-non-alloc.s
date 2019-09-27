// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %t -o %t2 -shared --apply-dynamic-relocs
// RUN: llvm-readobj -S --section-data -r %t2 | FileCheck -check-prefix CHECK -check-prefix APPLYDYNREL %s

// RUN: ld.lld %t -o %t2 -shared
// RUN: llvm-readobj -S --section-data -r %t2 | FileCheck -check-prefix CHECK -check-prefix NOAPPLYDYNREL %s
// RUN: ld.lld %t -o %t2 -shared --no-apply-dynamic-relocs
// RUN: llvm-readobj -S --section-data -r %t2 | FileCheck -check-prefix CHECK -check-prefix NOAPPLYDYNREL %s

// APPLYDYNREL:      Name: .data
// APPLYDYNREL-NEXT: Type: SHT_PROGBITS
// APPLYDYNREL-NEXT: Flags [
// APPLYDYNREL-NEXT:   SHF_ALLOC
// APPLYDYNREL-NEXT:   SHF_WRITE
// APPLYDYNREL-NEXT: ]
// APPLYDYNREL-NEXT: Address: 0x2000
// APPLYDYNREL-NEXT: Offset: 0x2000
// APPLYDYNREL-NEXT: Size: 16
// APPLYDYNREL-NEXT: Link: 0
// APPLYDYNREL-NEXT: Info: 0
// APPLYDYNREL-NEXT: AddressAlignment: 1
// APPLYDYNREL-NEXT: EntrySize: 0
// APPLYDYNREL-NEXT: SectionData (
// APPLYDYNREL-NEXT:   0000: 00200000 00000000 00000000 00000000
// APPLYDYNREL-NEXT: )

// NOAPPLYDYNREL:      Name: .data
// NOAPPLYDYNREL-NEXT: Type: SHT_PROGBITS
// NOAPPLYDYNREL-NEXT: Flags [
// NOAPPLYDYNREL-NEXT:   SHF_ALLOC
// NOAPPLYDYNREL-NEXT:   SHF_WRITE
// NOAPPLYDYNREL-NEXT: ]
// NOAPPLYDYNREL-NEXT: Address: 0x2000
// NOAPPLYDYNREL-NEXT: Offset: 0x2000
// NOAPPLYDYNREL-NEXT: Size: 16
// NOAPPLYDYNREL-NEXT: Link: 0
// NOAPPLYDYNREL-NEXT: Info: 0
// NOAPPLYDYNREL-NEXT: AddressAlignment: 1
// NOAPPLYDYNREL-NEXT: EntrySize: 0
// NOAPPLYDYNREL-NEXT: SectionData (
// NOAPPLYDYNREL-NEXT:   0000: 00000000 00000000 00000000 00000000
// NOAPPLYDYNREL-NEXT: )

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
// CHECK-NEXT:   0000: 00200000 00000000 00200000 00000000
// CHECK-NEXT:   0010: 00200000 00000000 00200000 00000000
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.}}) .rela.dyn {
// CHECK-NEXT:     0x2000 R_X86_64_RELATIVE - 0x2000
// CHECK-NEXT:     0x2008 R_X86_64_64 zed 0x0
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
