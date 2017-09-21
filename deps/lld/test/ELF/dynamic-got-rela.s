// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -r -s -l -section-data %t.so | FileCheck %s

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x[[GOT:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00000000 00000000                |
// CHECK-NEXT: )

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
