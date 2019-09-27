# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc-unknown-freebsd %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj --file-headers --sections --section-data -l %t | FileCheck %s

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
// CHECK-NEXT:   Type: Executable (0x2)
// CHECK-NEXT:   Machine: EM_PPC (0x14)
// CHECK-NEXT:   Version: 1
// CHECK-NEXT:   Entry: 0x10010000
// CHECK-NEXT:   ProgramHeaderOffset: 0x34
// CHECK-NEXT:   SectionHeaderOffset: 0x11044
// CHECK-NEXT:   Flags [ (0x0)
// CHECK-NEXT:   ]
// CHECK-NEXT:   HeaderSize: 52
// CHECK-NEXT:   ProgramHeaderEntrySize: 32
// CHECK-NEXT:   ProgramHeaderCount: 4
// CHECK-NEXT:   SectionHeaderEntrySize: 40
// CHECK-NEXT:   SectionHeaderCount: 6
// CHECK-NEXT:   StringTableSectionIndex: 4
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
// CHECK-NEXT:     Name: .text
// CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       SHF_ALLOC (0x2)
// CHECK-NEXT:       SHF_EXECINSTR (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x10010000
// CHECK-NEXT:     Offset: 0x10000
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
// CHECK-NEXT:     Index: 2
// CHECK-NEXT:     Name: .comment
// CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:     Flags [ (0x30)
// CHECK-NEXT:       SHF_MERGE (0x10)
// CHECK-NEXT:       SHF_STRINGS (0x20)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x11000
// CHECK-NEXT:     Size: 8
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 1
// CHECK:        }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 3
// CHECK-NEXT:     Name: .symtab
// CHECK-NEXT:     Type: SHT_SYMTAB (0x2)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x11008
// CHECK-NEXT:     Size: 16
// CHECK-NEXT:     Link: 5
// CHECK-NEXT:     Info: 1
// CHECK-NEXT:     AddressAlignment: 4
// CHECK-NEXT:     EntrySize: 16
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00000000 00000000 00000000 00000000  |................|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 4
// CHECK-NEXT:     Name: .shstrtab
// CHECK-NEXT:     Type: SHT_STRTAB (0x3)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x11018
// CHECK-NEXT:     Size: 42
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 0
// CHECK:        }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index: 5
// CHECK-NEXT:     Name: .strtab
// CHECK-NEXT:     Type: SHT_STRTAB (0x3)
// CHECK-NEXT:     Flags [ (0x0)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x0
// CHECK-NEXT:     Offset: 0x11042
// CHECK-NEXT:     Size: 1
// CHECK-NEXT:     Link: 0
// CHECK-NEXT:     Info: 0
// CHECK-NEXT:     AddressAlignment: 1
// CHECK-NEXT:     EntrySize: 0
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 00
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT: ]
// CHECK-NEXT: ProgramHeaders [
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_PHDR (0x6)
// CHECK-NEXT:     Offset: 0x34
// CHECK-NEXT:     VirtualAddress: 0x10000034
// CHECK-NEXT:     PhysicalAddress: 0x10000034
// CHECK-NEXT:     FileSize: 128
// CHECK-NEXT:     MemSize: 128
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     VirtualAddress: 0x10000000
// CHECK-NEXT:     PhysicalAddress: 0x10000000
// CHECK-NEXT:     FileSize: 180
// CHECK-NEXT:     MemSize: 180
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 65536
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x1000
// CHECK-NEXT:     VirtualAddress: 0x10010000
// CHECK-NEXT:     PhysicalAddress: 0x10010000
// CHECK-NEXT:     FileSize: 4096
// CHECK-NEXT:     MemSize: 4096
// CHECK-NEXT:     Flags [ (0x5)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_X (0x1)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 65536
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
