// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld --hash-style=sysv -shared %t2.o -o %t2.so
// RUN: llvm-readobj -s %t2.so | FileCheck --check-prefix=SO %s
// RUN: ld.lld --hash-style=sysv -dynamic-linker /lib64/ld-linux-x86-64.so.2 -rpath foo -rpath bar --export-dynamic %t.o %t2.so -o %t
// RUN: llvm-readobj --program-headers --dynamic-table -t -s -dyn-symbols -section-data -hash-table %t | FileCheck %s
// RUN: ld.lld --hash-style=sysv %t.o %t2.so %t2.so -o %t2
// RUN: llvm-readobj -dyn-symbols %t2 | FileCheck --check-prefix=DONT_EXPORT %s

// Make sure .symtab is properly aligned.
// SO:      Name: .symtab
// SO-NEXT: Type: SHT_SYMTAB
// SO-NEXT: Flags [
// SO-NEXT: ]
// SO-NEXT: Address:
// SO-NEXT: Offset: 0x1038
// SO-NEXT: Size:
// SO-NEXT: Link:
// SO-NEXT: Info:
// SO-NEXT: AddressAlignment: 4

// CHECK:        Name: .interp
// CHECK-NEXT:   Type: SHT_PROGBITS
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: [[INTERPADDR:.*]]
// CHECK-NEXT:   Offset: [[INTERPOFFSET:.*]]
// CHECK-NEXT:   Size: [[INTERPSIZE:.*]]
// CHECK-NEXT:   Link: 0
// CHECK-NEXT:   Info: 0
// CHECK-NEXT:   AddressAlignment: 1
// CHECK-NEXT:   EntrySize: 0
// CHECK-NEXT:   SectionData (
// CHECK-NEXT:     0000: 2F6C6962 36342F6C 642D6C69 6E75782D  |/lib64/ld-linux-|
// CHECK-NEXT:     0010: 7838362D 36342E73 6F2E3200           |x86-64.so.2.|
// CHECK-NEXT:   )
// CHECK-NEXT: }

// test that .hash is linked to .dynsym
// CHECK:        Index: 2
// CHECK-NEXT:   Name: .dynsym
// CHECK-NEXT:   Type: SHT_DYNSYM
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: [[DYNSYMADDR:.*]]
// CHECK-NEXT:   Offset: 0x150
// CHECK-NEXT:   Size:
// CHECK-NEXT:   Link: [[DYNSTR:.*]]
// CHECK-NEXT:   Info: 1
// CHECK-NEXT:   AddressAlignment: 4
// CHECK-NEXT:   EntrySize: 16
// CHECK-NEXT:   SectionData (
// CHECK-NEXT:     0000:
// CHECK-NEXT:     0010:
// CHECK-NEXT:     0020:
// CHECK-NEXT:     0030:
// CHECK-NEXT:   )
// CHECK-NEXT: }
// CHECK-NEXT: Section {
// CHECK-NEXT:   Index: 3
// CHECK-NEXT:    Name: .hash
// CHECK-NEXT:    Type: SHT_HASH
// CHECK-NEXT:    Flags [
// CHECK-NEXT:      SHF_ALLOC
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: [[HASHADDR:.*]]
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size:
// CHECK-NEXT:    Link: 2
// CHECK-NEXT:    Info: 0
// CHECK-NEXT:    AddressAlignment: 4
// CHECK-NEXT:    EntrySize: 4
// CHECK:      Section {
// CHECK-NEXT:   Index: [[DYNSTR]]
// CHECK-NEXT:   Name: .dynstr
// CHECK-NEXT:   Type: SHT_STRTAB
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: [[DYNSTRADDR:.*]]
// CHECK-NEXT:   Offset:
// CHECK-NEXT:   Size:
// CHECK-NEXT:   Link: 0
// CHECK-NEXT:   Info: 0
// CHECK-NEXT:   AddressAlignment: 1
// CHECK-NEXT:   EntrySize: 0

// CHECK:      Name: .rel.dyn
// CHECK-NEXT: Type: SHT_REL
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT: ]
// CHECK-NEXT: Address: [[RELADDR:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: [[RELSIZE:.*]]
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize: [[RELENT:.*]]

// CHECK:        Name: .dynamic
// CHECK-NEXT:   Type: SHT_DYNAMIC
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:     SHF_WRITE
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: [[ADDR:.*]]
// CHECK-NEXT:   Offset: [[OFFSET:.*]]
// CHECK-NEXT:   Size: [[SIZE:.*]]
// CHECK-NEXT:   Link: [[DYNSTR]]
// CHECK-NEXT:   Info: 0
// CHECK-NEXT:   AddressAlignment: [[ALIGN:.*]]
// CHECK-NEXT:   EntrySize: 8
// CHECK-NEXT:   SectionData (
// CHECK:        )

// CHECK:      Name: .symtab
// CHECK-NEXT: Type: SHT_SYMTAB
// CHECK-NEXT: Flags [
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize: [[SYMENT:.*]]

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _DYNAMIC
// CHECK-NEXT:     Value: 0x12000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .dynamic
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _start
// CHECK-NEXT:     Value: 0x11000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: bar
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Function
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: zed
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global (0x1)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: @
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _start@
// CHECK-NEXT:     Value: 0x11000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Non
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: bar@
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Function
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: zed@
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// DONT_EXPORT:      DynamicSymbols [
// DONT_EXPORT-NEXT:   Symbol {
// DONT_EXPORT-NEXT:     Name: @
// DONT_EXPORT-NEXT:     Value: 0x0
// DONT_EXPORT-NEXT:     Size: 0
// DONT_EXPORT-NEXT:     Binding: Local (0x0)
// DONT_EXPORT-NEXT:     Type: None (0x0)
// DONT_EXPORT-NEXT:     Other: 0
// DONT_EXPORT-NEXT:     Section: Undefined (0x0)
// DONT_EXPORT-NEXT:   }
// DONT_EXPORT-NEXT:   Symbol {
// DONT_EXPORT-NEXT:     Name: bar@
// DONT_EXPORT-NEXT:     Value: 0x0
// DONT_EXPORT-NEXT:     Size: 0
// DONT_EXPORT-NEXT:     Binding: Global
// DONT_EXPORT-NEXT:     Type: Function
// DONT_EXPORT-NEXT:     Other: 0
// DONT_EXPORT-NEXT:     Section: Undefined
// DONT_EXPORT-NEXT:   }
// DONT_EXPORT-NEXT:   Symbol {
// DONT_EXPORT-NEXT:     Name: zed@
// DONT_EXPORT-NEXT:     Value: 0x0
// DONT_EXPORT-NEXT:     Size: 0
// DONT_EXPORT-NEXT:     Binding: Global
// DONT_EXPORT-NEXT:     Type: None
// DONT_EXPORT-NEXT:     Other: 0
// DONT_EXPORT-NEXT:     Section: Undefined
// DONT_EXPORT-NEXT:   }
// DONT_EXPORT-NEXT: ]

// CHECK:      DynamicSection [
// CHECK-NEXT:   Tag        Type                 Name/Value
// CHECK-NEXT:   0x0000001D RUNPATH              foo:bar
// CHECK-NEXT:   0x00000001 NEEDED               Shared library: [{{.*}}2.so]
// CHECK-NEXT:   0x00000015 DEBUG                0x0
// CHECK-NEXT:   0x00000011 REL                  [[RELADDR]]
// CHECK-NEXT:   0x00000012 RELSZ                [[RELSIZE]] (bytes)
// CHECK-NEXT:   0x00000013 RELENT               [[RELENT]] (bytes)
// CHECK-NEXT:   0x00000006 SYMTAB               [[DYNSYMADDR]]
// CHECK-NEXT:   0x0000000B SYMENT               [[SYMENT]] (bytes)
// CHECK-NEXT:   0x00000005 STRTAB               [[DYNSTRADDR]]
// CHECK-NEXT:   0x0000000A STRSZ
// CHECK-NEXT:   0x00000004 HASH                 [[HASHADDR]]
// CHECK-NEXT:   0x00000000 NULL                 0x0
// CHECK-NEXT: ]

// CHECK:     ProgramHeaders [
// CHECK:        Type: PT_INTERP
// CHECK-NEXT:   Offset: [[INTERPOFFSET]]
// CHECK-NEXT:   VirtualAddress: [[INTERPADDR]]
// CHECK-NEXT:   PhysicalAddress: [[INTERPADDR]]
// CHECK-NEXT:   FileSize: [[INTERPSIZE]]
// CHECK-NEXT:   MemSize: [[INTERPSIZE]]
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     PF_R
// CHECK-NEXT:   ]
// CHECK-NEXT:   Alignment: 1
// CHECK-NEXT: }
// CHECK:        Type: PT_DYNAMIC
// CHECK-NEXT:   Offset: [[OFFSET]]
// CHECK-NEXT:   VirtualAddress: [[ADDR]]
// CHECK-NEXT:   PhysicalAddress: [[ADDR]]
// CHECK-NEXT:   FileSize: [[SIZE]]
// CHECK-NEXT:   MemSize: [[SIZE]]
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     PF_R
// CHECK-NEXT:     PF_W
// CHECK-NEXT:   ]
// CHECK-NEXT:   Alignment: [[ALIGN]]
// CHECK-NEXT: }

// CHECK:      HashTable {
// CHECK-NEXT:   Num Buckets: 4
// CHECK-NEXT:   Num Chains: 4
// CHECK-NEXT:   Buckets: [3, 0, 2, 0]
// CHECK-NEXT:   Chains: [0, 0, 0, 1]
// CHECK-NEXT: }

.global _start
_start:
.long bar@GOT
.long zed@GOT
