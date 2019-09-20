## The test file contains an STT_TLS symbol but has no TLS section.
## Check we report an error properly.

# RUN: yaml2obj %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: has an STT_TLS symbol but doesn't have an SHF_TLS section

--- !ELF
FileHeader:      
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:        
  - Name:            .text
    Type:            SHT_PROGBITS
    Flags:           [ SHF_ALLOC, SHF_EXECINSTR ]
    Content:         ''
Symbols:
  - Name:          bar
    Type:          STT_TLS
    Section:       .text
    Binding:       STB_GLOBAL
