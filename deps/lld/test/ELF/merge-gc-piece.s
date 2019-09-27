# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.so -shared --gc-sections
# RUN: llvm-readobj -S --section-data %t.so | FileCheck %s


# CHECK:      Name: .foo
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT: ]
# CHECK-NEXT: Address: 0x1FD

# CHECK:      Name: .bar
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 16
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: FE010000 00000000 FF010000 00000000
# CHECK-NEXT: )

        .section .foo,"aM",@progbits,8
        .quad 42
        .global sym
sym:
        .quad 43

        .section .bar
        .quad .foo + 1
        .quad .foo + 2
