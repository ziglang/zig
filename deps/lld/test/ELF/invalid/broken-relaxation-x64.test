# REQUIRES: x86

# RUN: yaml2obj %s -o %t.o
# RUN: not ld.lld %t.o -o %t.exe 2>&1 | FileCheck --check-prefix=ERR %s
# ERR: R_X86_64_GOTTPOFF must be used in MOVQ or ADDQ instructions only
# ERR: R_X86_64_GOTTPOFF must be used in MOVQ or ADDQ instructions only

## YAML below contains 2 relocations of type R_X86_64_GOTTPOFF, and a .text
## with fake content filled by 0xFF. That means instructions for relaxation are
## "broken", so they does not match any known valid relaxations. We also generate
## .tls section because we need it for correct proccessing of STT_TLS symbol.
!ELF
FileHeader:
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  OSABI:           ELFOSABI_FREEBSD
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:
  - Type:            SHT_PROGBITS
    Name:            .text
    Flags:           [ SHF_ALLOC, SHF_EXECINSTR ]
    AddressAlign:    0x04
    Content:         "FFFFFFFFFFFFFFFF"
  - Type:            SHT_PROGBITS
    Name:            .tls
    Flags:           [ SHF_ALLOC, SHF_TLS ]
  - Type:            SHT_REL
    Name:            .rel.text
    Link:            .symtab
    Info:            .text
    AddressAlign:    0x04
    Relocations:
      - Offset:          4
        Symbol:          foo
        Type:            R_X86_64_GOTTPOFF
      - Offset:          4
        Symbol:          foo
        Type:            R_X86_64_GOTTPOFF
Symbols:
  Global:
    - Name:     foo
      Type:     STT_TLS
      Section:  .text
      Value:    0x12345
      Size:     4
