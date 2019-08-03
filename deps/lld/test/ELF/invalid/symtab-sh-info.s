## .symtab's sh_info contains zero value. First entry in a .symtab is a
## zero entry that must exist in a valid object, so sh_info can't be null.
## Check we report a proper error for that case.
# RUN: yaml2obj -docnum=1 %s -o %t.o
# RUN: not ld.lld %t.o -o %t2 2>&1 | FileCheck %s --check-prefix=ERR1
# ERR1: invalid sh_info in symbol table

--- !ELF
FileHeader:
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:
  - Name:            .symtab
    Info:            0
    Type:            SHT_SYMTAB
Symbols:
  - Name:          foo
    Binding:       STB_GLOBAL

## sh_info has value 2 what says that non-local symbol `foo` is local.
## Check we report this case.
# RUN: yaml2obj -docnum=2 %s -o %t.o
# RUN: not ld.lld %t.o -o %t2 2>&1 | FileCheck --check-prefix=ERR2 %s
# ERR2: broken object: getLocalSymbols returns a non-local symbol

--- !ELF
FileHeader:
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:
  - Name:            .symtab
    Info:            2
    Type:            SHT_SYMTAB
Symbols:
  - Name:          foo
    Binding:       STB_GLOBAL

## sh_info has value 0xff what is larger than number of symbols in a .symtab.
## Check we report this case.
# RUN: yaml2obj -docnum=3 %s -o %t.o
# RUN: not ld.lld %t.o -o %t2 2>&1 | FileCheck --check-prefix=ERR1 %s

--- !ELF
FileHeader:
  Class:           ELFCLASS64
  Data:            ELFDATA2LSB
  Type:            ET_REL
  Machine:         EM_X86_64
Sections:
  - Name:            .symtab
    Info:            0xff
    Type:            SHT_SYMTAB
Symbols:
  - Name:          foo
    Binding:       STB_GLOBAL
