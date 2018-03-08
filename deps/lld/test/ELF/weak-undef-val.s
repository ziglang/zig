# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --export-dynamic
# RUN: llvm-readobj -s -section-data %t | FileCheck %s

# CHECK:      Name: .text
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_EXECINSTR
# CHECK-NEXT: ]
# CHECK-NEXT: Address: 0x201000
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size:
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 00F0DFFF                             |
# CHECK-NEXT: )

        .global _start
_start:
        .weak foobar
        .long foobar - .
