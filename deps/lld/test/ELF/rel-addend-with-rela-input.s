# REQUIRES: mips
# Check that we correctly write addends if the output use Elf_Rel but the input
# uses Elf_Rela

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t-rela.o
# RUN: llvm-readobj -h -S --section-data -r %t-rela.o | FileCheck -check-prefix INPUT-RELA %s
# INPUT-RELA:  ElfHeader {
# INPUT-RELA:     Class: 64-bit
# INPUT-RELA:     DataEncoding: BigEndian
# INPUT-RELA:   Section {
# INPUT-RELA:       Name: .data
# INPUT-RELA:       SectionData (
# INPUT-RELA-NEXT:    0000: 00000000 00000000 ABCDEF00 12345678 |.............4Vx|
#                              ^--- No addend here since it uses RELA
# INPUT-RELA:     Relocations [
# INPUT-RELA-NEXT:  Section ({{.+}}) .rela.data {
# INPUT-RELA-NEXT:     0x0 R_MIPS_64/R_MIPS_NONE/R_MIPS_NONE foo 0x5544
# INPUT-RELA-NEXT:  }
# INPUT-RELA-NEXT: ]

# Previously the addend to the dynamic relocation in the .data section was not copied if
# the input file used RELA and the output uses REL. Check that it works now:
# RUN: ld.lld -shared -o %t.so %t-rela.o  -verbose
# RUN: llvm-readobj -h -S --section-data -r %t.so | FileCheck -check-prefix RELA-TO-REL %s
# RELA-TO-REL:  ElfHeader {
# RELA-TO-REL:    Class: 64-bit
# RELA-TO-REL:    DataEncoding: BigEndian
# RELA-TO-REL:  Section {
# RELA-TO-REL:       Name: .data
# RELA-TO-REL:       SectionData (
# RELA-TO-REL-NEXT:    0000: 00000000 00005544 ABCDEF00 12345678 |......UD.....4Vx|
#                                        ^--- Addend for relocation in .rel.dyn
# RELA-TO-REL:     Relocations [
# RELA-TO-REL-NEXT:  Section ({{.+}}) .rel.dyn {
# RELA-TO-REL-NEXT:     0x10000 R_MIPS_REL32/R_MIPS_64/R_MIPS_NONE foo 0x0
# RELA-TO-REL-NEXT:  }
# RELA-TO-REL-NEXT: ]

.extern foo

.data
.quad foo + 0x5544
.quad 0xabcdef0012345678
