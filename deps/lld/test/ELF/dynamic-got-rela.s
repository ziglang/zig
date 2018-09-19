// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared --apply-dynamic-relocs
// RUN: llvm-readobj -r -s -l -section-data %t.so | FileCheck -check-prefix CHECK -check-prefix APPLYDYNREL %s
// RUN: ld.lld %t.o -o %t2.so -shared
// RUN: llvm-readobj -r -s -l -section-data %t2.so | FileCheck -check-prefix CHECK -check-prefix NOAPPLYDYNREL %s
// RUN: ld.lld %t.o -o %t2.so -shared --no-apply-dynamic-relocs
// RUN: llvm-readobj -r -s -l -section-data %t2.so | FileCheck -check-prefix CHECK -check-prefix NOAPPLYDYNREL %s

// APPLYDYNREL:      Name: .got
// APPLYDYNREL-NEXT: Type: SHT_PROGBITS
// APPLYDYNREL-NEXT: Flags [
// APPLYDYNREL-NEXT:   SHF_ALLOC
// APPLYDYNREL-NEXT:   SHF_WRITE
// APPLYDYNREL-NEXT: ]
// APPLYDYNREL-NEXT: Address: 0x[[GOT:.*]]
// APPLYDYNREL-NEXT: Offset:
// APPLYDYNREL-NEXT: Size:
// APPLYDYNREL-NEXT: Link:
// APPLYDYNREL-NEXT: Info:
// APPLYDYNREL-NEXT: AddressAlignment:
// APPLYDYNREL-NEXT: EntrySize:
// APPLYDYNREL-NEXT: SectionData (
// APPLYDYNREL-NEXT:   0000: 00200000 00000000                |
// APPLYDYNREL-NEXT: )

// NOAPPLYDYNREL:      Name: .got
// NOAPPLYDYNREL-NEXT: Type: SHT_PROGBITS
// NOAPPLYDYNREL-NEXT: Flags [
// NOAPPLYDYNREL-NEXT:   SHF_ALLOC
// NOAPPLYDYNREL-NEXT:   SHF_WRITE
// NOAPPLYDYNREL-NEXT: ]
// NOAPPLYDYNREL-NEXT: Address: 0x[[GOT:.*]]
// NOAPPLYDYNREL-NEXT: Offset:
// NOAPPLYDYNREL-NEXT: Size:
// NOAPPLYDYNREL-NEXT: Link:
// NOAPPLYDYNREL-NEXT: Info:
// NOAPPLYDYNREL-NEXT: AddressAlignment:
// NOAPPLYDYNREL-NEXT: EntrySize:
// NOAPPLYDYNREL-NEXT: SectionData (
// NOAPPLYDYNREL-NEXT:   0000: 00000000 00000000                |
// NOAPPLYDYNREL-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x[[GOT]] R_X86_64_RELATIVE - 0x[[ADDEND:.*]]
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK:      Type: PT_DYNAMIC
// CHECK-NEXT: Offset: 0x[[ADDEND]]
// CHECK-NEXT: VirtualAddress: 0x[[ADDEND]]
// CHECK-NEXT: PhysicalAddress: 0x[[ADDEND]]

cmpq    $0, _DYNAMIC@GOTPCREL(%rip)
