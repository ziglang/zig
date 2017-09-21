# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-readobj -file-headers -sections -program-headers -symbols %t2 \
# RUN:   | FileCheck %s
# REQUIRES: aarch64

# exits with return code 42 on FreeBSD/AArch64
.globl _start
_start:
  mov    x0, 42
  mov    x8, 1
  svc    0

# CHECK:      ElfHeader {
# CHECK-NEXT:   Ident {
# CHECK-NEXT:     Magic: (7F 45 4C 46)
# CHECK-NEXT:     Class: 64-bit (0x2)
# CHECK-NEXT:     DataEncoding: LittleEndian (0x1)
# CHECK-NEXT:     FileVersion: 1
# CHECK-NEXT:     OS/ABI: FreeBSD (0x9)
# CHECK-NEXT:     ABIVersion: 0
# CHECK-NEXT:     Unused: (00 00 00 00 00 00 00)
# CHECK-NEXT:   }
# CHECK-NEXT:   Type: Executable (0x2)
# CHECK-NEXT:   Machine: EM_AARCH64 (0xB7)
# CHECK-NEXT:   Version: 1
# CHECK-NEXT:   Entry: [[ENTRY:0x[0-9A-F]+]]
# CHECK-NEXT:   ProgramHeaderOffset: 0x40
# CHECK-NEXT:   SectionHeaderOffset: 0x10098
# CHECK-NEXT:   Flags [ (0x0)
# CHECK-NEXT:   ]
# CHECK-NEXT:   HeaderSize: 64
# CHECK-NEXT:   ProgramHeaderEntrySize: 56
# CHECK-NEXT:   ProgramHeaderCount: 4
# CHECK-NEXT:   SectionHeaderEntrySize: 64
# CHECK-NEXT:   SectionHeaderCount: 6
# CHECK-NEXT:   StringTableSectionIndex: 4
# CHECK-NEXT: }
# CHECK-NEXT: Sections [
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 0
# CHECK-NEXT:     Name:  (0)
# CHECK-NEXT:     Type: SHT_NULL (0x0)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 0
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 1
# CHECK-NEXT:     Name: .text
# CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-NEXT:     Flags [ (0x6)
# CHECK-NEXT:       SHF_ALLOC (0x2)
# CHECK-NEXT:       SHF_EXECINSTR (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x20000
# CHECK-NEXT:     Offset: 0x10000
# CHECK-NEXT:     Size: 12
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 4
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 2
# CHECK-NEXT:     Name: .comment
# CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-NEXT:     Flags [ (0x30)
# CHECK-NEXT:       SHF_MERGE (0x10)
# CHECK-NEXT:       SHF_STRINGS (0x20)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x1000C
# CHECK-NEXT:     Size: 8
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 3
# CHECK-NEXT:     Name: .symtab
# CHECK-NEXT:     Type: SHT_SYMTAB (0x2)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x10018
# CHECK-NEXT:     Size: 72
# CHECK-NEXT:     Link: 5
# CHECK-NEXT:     Info: 2
# CHECK-NEXT:     AddressAlignment: 8
# CHECK-NEXT:     EntrySize: 24
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 4
# CHECK-NEXT:     Name: .shstrtab
# CHECK-NEXT:     Type: SHT_STRTAB (0x3)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x10060
# CHECK-NEXT:     Size: 42
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 5
# CHECK-NEXT:     Name: .strtab
# CHECK-NEXT:     Type: SHT_STRTAB (0x3)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x1008A
# CHECK-NEXT:     Size: 13
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:  (0)
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local (0x0)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: $x.0
# CHECK-NEXT:     Value: 0x20000
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local (0x0)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: _start
# CHECK-NEXT:     Value: [[ENTRY]]
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_PHDR (0x6)
# CHECK-NEXT:     Offset: 0x40
# CHECK-NEXT:     VirtualAddress: 0x10040
# CHECK-NEXT:     PhysicalAddress: 0x10040
# CHECK-NEXT:     FileSize: 224
# CHECK-NEXT:     MemSize: 224
# CHECK-NEXT:     Flags [ (0x4)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 8
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x10000
# CHECK-NEXT:     PhysicalAddress: 0x10000
# CHECK-NEXT:     FileSize: 288
# CHECK-NEXT:     MemSize: 288
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 65536
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x20000
# CHECK-NEXT:     PhysicalAddress: 0x20000
# CHECK-NEXT:     FileSize: 12
# CHECK-NEXT:     MemSize: 12
# CHECK-NEXT:     Flags [ (0x5)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:       PF_X (0x1)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 65536
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_GNU_STACK
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x0
# CHECK-NEXT:     PhysicalAddress: 0x0
# CHECK-NEXT:     FileSize: 0
# CHECK-NEXT:     MemSize: 0
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_W
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 0
# CHECK-NEXT:   }
# CHECK-NEXT: ]
