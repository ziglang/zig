# REQUIRES: ppc
# # RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t
# RUN: ld.lld --hash-style=sysv -discard-all -shared %t -o %t2
# RUN: llvm-readobj -file-headers -sections -section-data -program-headers %t2 | FileCheck %s
.abiversion 2
# Exits with return code 55 on linux.
.text
  li 0,1
  li 3,55
  sc

// CHECK:Format: ELF64-ppc64
// CHECK-NEXT:Arch: powerpc64le
// CHECK-NEXT:AddressSize: 64bit
// CHECK-NEXT:LoadName: 
// CHECK-NEXT:ElfHeader {
// CHECK-NEXT:  Ident {
// CHECK-NEXT:    Magic: (7F 45 4C 46)
// CHECK-NEXT:    Class: 64-bit (0x2)
// CHECK-NEXT:    DataEncoding: LittleEndian (0x1)
// CHECK-NEXT:    FileVersion: 1
// CHECK-NEXT:    OS/ABI: SystemV (0x0)
// CHECK-NEXT:    ABIVersion: 0
// CHECK-NEXT:    Unused: (00 00 00 00 00 00 00)
// CHECK-NEXT:  }
// CHECK-NEXT:  Type: SharedObject (0x3)
// CHECK-NEXT:  Machine: EM_PPC64 (0x15)
// CHECK-NEXT:  Version: 1
// CHECK-NEXT:  Entry: 0x10000
// CHECK-NEXT:  ProgramHeaderOffset: 0x40
// CHECK-NEXT:  SectionHeaderOffset:
// CHECK-NEXT:  Flags [ (0x2)
// CHECK-NEXT:    0x2
// CHECK-NEXT:  ]
// CHECK-NEXT:  HeaderSize: 64
// CHECK-NEXT:  ProgramHeaderEntrySize: 56
// CHECK-NEXT:  ProgramHeaderCount: 7
// CHECK-NEXT:  SectionHeaderEntrySize: 64
// CHECK-NEXT:  SectionHeaderCount: 10
// CHECK-NEXT:  StringTableSectionIndex: 8
// CHECK-NEXT:}
// CHECK-NEXT:Sections [
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 0
// CHECK-NEXT:    Name:  (0)
// CHECK-NEXT:    Type: SHT_NULL (0x0)
// CHECK-NEXT:    Flags [ (0x0)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x0
// CHECK-NEXT:    Offset: 0x0
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 0
// CHECK-NEXT:    EntrySize: 0
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 1
// CHECK-NEXT:    Name: .dynsym (1)
// CHECK-NEXT:    Type: SHT_DYNSYM (0xB)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x1C8
// CHECK-NEXT:    Offset: 0x1C8
// CHECK-NEXT:    Size: 24
// CHECK-NEXT:    Link: 3
// CHECK-NEXT:    Info: 1
// CHECK-NEXT:    AddressAlignment: 8
// CHECK-NEXT:    EntrySize: 24
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:      0010: 00000000 00000000                    |........|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 2
// CHECK-NEXT:    Name: .hash (9)
// CHECK-NEXT:    Type: SHT_HASH (0x5)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x1E0
// CHECK-NEXT:    Offset: 0x1E0
// CHECK-NEXT:    Size: 16
// CHECK-NEXT:    Link: 1
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 4
// CHECK-NEXT:    EntrySize: 4
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 01000000 01000000 00000000 00000000  |................|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 3
// CHECK-NEXT:    Name: .dynstr (15)
// CHECK-NEXT:    Type: SHT_STRTAB (0x3)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x1F0
// CHECK-NEXT:    Offset: 0x1F0
// CHECK-NEXT:    Size: 1
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 1
// CHECK-NEXT:    EntrySize: 0
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 00                                   |.|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 4
// CHECK-NEXT:    Name: .text (23)
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [ (0x6)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_EXECINSTR (0x4)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x10000
// CHECK-NEXT:    Offset: 0x10000
// CHECK-NEXT:    Size: 12
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 4
// CHECK-NEXT:    EntrySize: 0
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 01000038 37006038 02000044           |...87.`8...D|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 5
// CHECK-NEXT:    Name: .dynamic (29)
// CHECK-NEXT:    Type: SHT_DYNAMIC (0x6)
// CHECK-NEXT:    Flags [ (0x3)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_WRITE (0x1)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x20000
// CHECK-NEXT:    Offset: 0x20000
// CHECK-NEXT:    Size: 96
// CHECK-NEXT:    Link: 3
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 8
// CHECK-NEXT:    EntrySize: 16
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 06000000 00000000 C8010000 00000000  |................|
// CHECK-NEXT:      0010: 0B000000 00000000 18000000 00000000  |................|
// CHECK-NEXT:      0020: 05000000 00000000 F0010000 00000000  |................|
// CHECK-NEXT:      0030: 0A000000 00000000 01000000 00000000  |................|
// CHECK-NEXT:      0040: 04000000 00000000 E0010000 00000000  |................|
// CHECK-NEXT:      0050: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 6
// CHECK-NEXT:    Name: .comment (38)
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [ (0x30)
// CHECK-NEXT:      SHF_MERGE (0x10)
// CHECK-NEXT:      SHF_STRINGS (0x20)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x0
// CHECK-NEXT:    Offset: 0x20060
// CHECK-NEXT:    Size: 8
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 1
// CHECK-NEXT:    EntrySize: 1
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 4C4C4420 312E3000                    |LLD 1.0.|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 7
// CHECK-NEXT:    Name: .symtab (47)
// CHECK-NEXT:    Type: SHT_SYMTAB (0x2)
// CHECK-NEXT:    Flags [ (0x0)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x0
// CHECK-NEXT:    Offset: 0x20068
// CHECK-NEXT:    Size: 48
// CHECK-NEXT:    Link: 9
// CHECK-NEXT:    Info: 2
// CHECK-NEXT:    AddressAlignment: 8
// CHECK-NEXT:    EntrySize: 24
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:      0010: 00000000 00000000 01000000 00020500  |................|
// CHECK-NEXT:      0020: 00000200 00000000 00000000 00000000  |................|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 8
// CHECK-NEXT:    Name: .shstrtab (55)
// CHECK-NEXT:    Type: SHT_STRTAB (0x3)
// CHECK-NEXT:    Flags [ (0x0)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x0
// CHECK-NEXT:    Offset: 0x20098
// CHECK-NEXT:    Size: 73
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 1
// CHECK-NEXT:    EntrySize: 0
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 002E6479 6E73796D 002E6861 7368002E  |..dynsym..hash..|
// CHECK-NEXT:      0010: 64796E73 7472002E 74657874 002E6479  |dynstr..text..dy|
// CHECK-NEXT:      0020: 6E616D69 63002E63 6F6D6D65 6E74002E  |namic..comment..|
// CHECK-NEXT:      0030: 73796D74 6162002E 73687374 72746162  |symtab..shstrtab|
// CHECK-NEXT:      0040: 002E7374 72746162 00                 |..strtab.|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:  Section {
// CHECK-NEXT:    Index: 9
// CHECK-NEXT:    Name: .strtab (65)
// CHECK-NEXT:    Type: SHT_STRTAB (0x3)
// CHECK-NEXT:    Flags [ (0x0)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x0
// CHECK-NEXT:    Offset: 0x200E1
// CHECK-NEXT:    Size: 10
// CHECK-NEXT:    Link: 0
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 1
// CHECK-NEXT:    EntrySize: 0
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 005F4459 4E414D49 4300               |._DYNAMIC.|
// CHECK-NEXT:    )
// CHECK-NEXT:  }
// CHECK-NEXT:]
// CHECK-NEXT:ProgramHeaders [
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_PHDR (0x6)
// CHECK-NEXT:    Offset: 0x40
// CHECK-NEXT:    VirtualAddress: 0x40
// CHECK-NEXT:    PhysicalAddress: 0x40
// CHECK-NEXT:    FileSize: 392
// CHECK-NEXT:    MemSize: 392
// CHECK-NEXT:    Flags [ (0x4)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 8
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_LOAD (0x1)
// CHECK-NEXT:    Offset: 0x0
// CHECK-NEXT:    VirtualAddress: 0x0
// CHECK-NEXT:    PhysicalAddress: 0x0
// CHECK-NEXT:    FileSize: 497
// CHECK-NEXT:    MemSize: 497
// CHECK-NEXT:    Flags [ (0x4)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 65536
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_LOAD (0x1)
// CHECK-NEXT:    Offset: 0x10000
// CHECK-NEXT:    VirtualAddress: 0x10000
// CHECK-NEXT:    PhysicalAddress: 0x10000
// CHECK-NEXT:    FileSize: 12
// CHECK-NEXT:    MemSize: 12
// CHECK-NEXT:    Flags [ (0x5)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:      PF_X (0x1)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 65536
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_LOAD (0x1)
// CHECK-NEXT:    Offset: 0x20000
// CHECK-NEXT:    VirtualAddress: 0x20000
// CHECK-NEXT:    PhysicalAddress: 0x20000
// CHECK-NEXT:    FileSize: 96
// CHECK-NEXT:    MemSize: 96
// CHECK-NEXT:    Flags [ (0x6)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:      PF_W (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 65536
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_DYNAMIC (0x2)
// CHECK-NEXT:    Offset: 0x20000
// CHECK-NEXT:    VirtualAddress: 0x20000
// CHECK-NEXT:    PhysicalAddress: 0x20000
// CHECK-NEXT:    FileSize: 96
// CHECK-NEXT:    MemSize: 96
// CHECK-NEXT:    Flags [ (0x6)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:      PF_W (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 8
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_GNU_RELRO (0x6474E552)
// CHECK-NEXT:    Offset: 0x20000
// CHECK-NEXT:    VirtualAddress: 0x20000
// CHECK-NEXT:    PhysicalAddress: 0x20000
// CHECK-NEXT:    FileSize: 96
// CHECK-NEXT:    MemSize: 4096
// CHECK-NEXT:    Flags [ (0x4)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 1
// CHECK-NEXT:  }
// CHECK-NEXT:  ProgramHeader {
// CHECK-NEXT:    Type: PT_GNU_STACK (0x6474E551)
// CHECK-NEXT:    Offset: 0x0
// CHECK-NEXT:    VirtualAddress: 0x0
// CHECK-NEXT:    PhysicalAddress: 0x0
// CHECK-NEXT:    FileSize: 0
// CHECK-NEXT:    MemSize: 0
// CHECK-NEXT:    Flags [ (0x6)
// CHECK-NEXT:      PF_R (0x4)
// CHECK-NEXT:      PF_W (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Alignment: 0
// CHECK-NEXT:  }
// CHECK-NEXT:]
