# RUN: llvm-mc -filetype=obj -triple=powerpc-unknown-freebsd %s -o %t
# RUN: ld.lld --hash-style=sysv -discard-all -shared %t -o %t2
# RUN: llvm-readobj -file-headers -sections -section-data -program-headers %t2 | FileCheck %s
# REQUIRES: ppc

# exits with return code 42 on FreeBSD
.text
 li      0,1
 li      3,1
 sc

// CHECK: Format: ELF32-ppc
// CHECK-NEXT: Arch: powerpc
// CHECK-NEXT: AddressSize: 32bit
// CHECK-NEXT: LoadName:
// CHECK-NEXT: ElfHeader {
// CHECK-NEXT:   Ident {
// CHECK-NEXT:     Magic: (7F 45 4C 46)
// CHECK-NEXT:     Class: 32-bit (0x1)
// CHECK-NEXT:     DataEncoding: BigEndian (0x2)
// CHECK-NEXT:     FileVersion: 1
// CHECK-NEXT:     OS/ABI: FreeBSD (0x9)
// CHECK-NEXT:     ABIVersion: 0
// CHECK-NEXT:     Unused: (00 00 00 00 00 00 00)
// CHECK-NEXT:   }
// CHECK-NEXT:   Type: SharedObject (0x3)
// CHECK-NEXT:   Machine: EM_PPC (0x14)
// CHECK-NEXT:   Version: 1
// CHECK-NEXT:   Entry: 0x1000
// CHECK-NEXT:   ProgramHeaderOffset: 0x34
// CHECK-NEXT:   SectionHeaderOffset: 0x20AC
// CHECK-NEXT:   Flags [ (0x0)
// CHECK-NEXT:   ]
// CHECK-NEXT:   HeaderSize: 52
// CHECK-NEXT:   ProgramHeaderEntrySize: 32
// CHECK-NEXT:   ProgramHeaderCount: 7
// CHECK-NEXT:   SectionHeaderEntrySize: 40
// CHECK-NEXT:   SectionHeaderCount: 10
// CHECK-NEXT:   StringTableSectionIndex: 8
// CHECK-NEXT: }
// CHECK-NEXT: Sections [
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 0
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Type: SHT_NULL (0x0)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 0
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 1
// CHECK-NEXT:     Name: .dynsym
// CHECK-NEXT:     Type: SHT_DYNSYM (0xB)
// CHECK-NEXT:     Flags [ (0x2)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x114
// CHECK-NEXT:     Offset: 0x114
// CHECK-NEXT:     Size: 16
// CHECK-NEXT:     Link: 3
// CHECK-NEXT:     Info: 1
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 16
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 2
// CHECK-NEXT:     Name: .hash
// CHECK-NEXT:     Type: SHT_HASH (0x5)
// CHECK-NEXT:     Flags [ (0x2)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x124
// CHECK-NEXT:     Offset: 0x124
// CHECK-NEXT:     Size: 16
// CHECK-NEXT:     Link: 1
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 4
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00000001 00000001 00000000 00000000  |................|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 3
// CHECK-NEXT:     Name: .dynstr
// CHECK-NEXT:     Type: SHT_STRTAB (0x3)
// CHECK-NEXT:     Flags [ (0x2)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x134
// CHECK-NEXT:     Offset: 0x134
// CHECK-NEXT:     Size: 1
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00                                   |.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 4
// CHECK-NEXT:     Name: .text
// CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:       SHF_EXECINSTR (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x1000
// CHECK-NEXT:     Offset: 0x1000
// CHECK-NEXT:     Size: 12
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 38000001 38600001 44000002           |8...8`..D...|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 5
// CHECK-NEXT:     Name: .dynamic
// CHECK-NEXT:     Type: SHT_DYNAMIC (0x6)
// CHECK-NEXT:     Flags [ (0x3)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:       SHF_WRITE (0x1)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x2000
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     Size: 48
// CHECK-NEXT:     Link: 3
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 8
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00000006 00000114 0000000B 00000010  |................|
// CHECK-NEXT:       0010: 00000005 00000134 0000000A 00000001  |.......4........|
// CHECK-NEXT:       0020: 00000004 00000124 00000000 00000000  |.......$........|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 6
// CHECK-NEXT:     Name: .comment
// CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:     Flags [ (0x30)
// CHECK-NEXT:       SHF_MERGE (0x10)
// CHECK-NEXT:       SHF_STRINGS (0x20)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x2030
// CHECK-NEXT:     Size: 8
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 1
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 4C4C4420 312E3000 |LLD 1.0.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 7
// CHECK-NEXT:     Name: .symtab
// CHECK-NEXT:     Type: SHT_SYMTAB (0x2)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x2038
// CHECK-NEXT:     Size: 32
// CHECK-NEXT:     Link: 9
// CHECK-NEXT:     Info: 2
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 16
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:       0010: 00000001 00002000 00000000 00020005  |...... .........|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 8
// CHECK-NEXT:     Name: .shstrtab
// CHECK-NEXT:     Type: SHT_STRTAB (0x3)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x2058
// CHECK-NEXT:     Size: 73
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 002E6479 6E73796D 002E6861 7368002E  |..dynsym..hash..|
// CHECK-NEXT:       0010: 64796E73 7472002E 74657874 002E6479  |dynstr..text..dy|
// CHECK-NEXT:       0020: 6E616D69 63002E63 6F6D6D65 6E74002E  |namic..comment..|
// CHECK-NEXT:       0030: 73796D74 6162002E 73687374 72746162  |symtab..shstrtab|
// CHECK-NEXT:       0040: 002E7374 72746162 00                 |..strtab.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 9
// CHECK-NEXT:     Name: .strtab
// CHECK-NEXT:     Type: SHT_STRTAB (0x3)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x20A1
// CHECK-NEXT:     Size: 1
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 005F4459 4E414D49 4300               |._DYNAMIC.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT: ]
// CHECK-NEXT: ProgramHeaders [
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_PHDR (0x6)
// CHECK-NEXT:     Offset: 0x34
// CHECK-NEXT:     VirtualAddress: 0x34
// CHECK-NEXT:     PhysicalAddress: 0x34
// CHECK-NEXT:     FileSize: 224
// CHECK-NEXT:     MemSize: 224
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     VirtualAddress: 0x0
// CHECK-NEXT:     PhysicalAddress: 0x0
// CHECK-NEXT:     FileSize: 309
// CHECK-NEXT:     MemSize: 309
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4096
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x1000
// CHECK-NEXT:     VirtualAddress: 0x1000
// CHECK-NEXT:     PhysicalAddress: 0x1000
// CHECK-NEXT:     FileSize: 12
// CHECK-NEXT:     MemSize: 12
// CHECK-NEXT:     Flags [ (0x5)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_X (0x1)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4096
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     VirtualAddress: 0x2000
// CHECK-NEXT:     PhysicalAddress: 0x2000
// CHECK-NEXT:     FileSize: 48
// CHECK-NEXT:     MemSize: 48
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_W (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4096
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_DYNAMIC (0x2)
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     VirtualAddress: 0x2000
// CHECK-NEXT:     PhysicalAddress: 0x2000
// CHECK-NEXT:     FileSize: 48
// CHECK-NEXT:     MemSize: 48
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_W (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_GNU_RELRO (0x6474E552)
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     VirtualAddress: 0x2000
// CHECK-NEXT:     PhysicalAddress: 0x2000
// CHECK-NEXT:     FileSize: 48
// CHECK-NEXT:     MemSize: 4096
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 1
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_GNU_STACK (0x6474E551)
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     VirtualAddress: 0x0
// CHECK-NEXT:     PhysicalAddress: 0x0
// CHECK-NEXT:     FileSize: 0
// CHECK-NEXT:     MemSize: 0
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_W (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
