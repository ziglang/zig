# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -r -o %t2.o -O0
# RUN: llvm-readobj -s -section-data %t2.o | FileCheck %s

# We combine just the sections with the same name and sh_entsize.

# CHECK:      Name: .foo
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 16
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment: 8
# CHECK-NEXT: EntrySize: 8
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 41000000 00000000 42000000 00000000
# CHECK-NEXT: )

# CHECK:      Name: .foo
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 8
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment: 4
# CHECK-NEXT: EntrySize: 4
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 41000000 42000000
# CHECK-NEXT: )

        .section .foo, "aM",@progbits,8,unique,0
        .quad 0x41
        .section .foo, "aM",@progbits,8,unique,1
        .quad 0x42
        .section .foo, "aM",@progbits,4,unique,2
        .long 0x41
        .long 0x42
