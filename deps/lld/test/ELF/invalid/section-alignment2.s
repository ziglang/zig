# RUN: yaml2obj %s -o %t.o
# RUN: not ld.lld %t.o -o %tout 2>&1 | FileCheck %s

# CHECK: error: {{.*}}.o:(.text): sh_addralign is not a power of 2

!ELF
FileHeader:
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:
  - Name:            .text
    Type:            SHT_PROGBITS
    Flags:           [ SHF_ALLOC, SHF_EXECINSTR ]
    AddressAlign:    0x3
