# REQUIRES: x86
# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=i386-pc-linux
# RUN: ld.lld %t.o -o %t.so -shared
# RUN: llvm-readobj --relocations --sections --section-data %t.so | FileCheck %s

# Check that the value of a preemptible symbol is not written to the
# got entry when using Elf_Rel. It is not needed since the dynamic
# linker will write the final value.

# CHECK:      Name: .got
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_WRITE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 4
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 00000000
# CHECK-NEXT: )

# CHECK: R_386_GLOB_DAT bar 0x0

        movl    bar@GOT(%eax), %eax

        .data
        .globl  bar
bar:
        .long   42
