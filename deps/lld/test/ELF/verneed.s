# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/verneed1.s -o %t1.o
# RUN: echo "v1 {}; v2 {}; v3 { local: *; };" > %t.script
# RUN: ld.lld -shared %t1.o --version-script %t.script -o %t1.so -soname verneed1.so.0
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/verneed2.s -o %t2.o
# RUN: ld.lld -shared %t2.o --version-script %t.script -o %t2.so -soname verneed2.so.0

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv %t.o %t1.so %t2.so -o %t
# RUN: llvm-readobj -V --sections --section-data --dyn-syms --dynamic-table %t | FileCheck %s

# CHECK:        Section {
# CHECK:          Index: 1
# CHECK-NEXT:     Name: .dynsym
# CHECK-NEXT:     Type: SHT_DYNSYM (0xB)
# CHECK-NEXT:     Flags [ (0x2)
# CHECK-NEXT:       SHF_ALLOC (0x2)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x200200
# CHECK-NEXT:     Offset: 0x200
# CHECK-NEXT:     Size: 96
# CHECK-NEXT:     Link: [[DYNSTR:.*]]
# CHECK-NEXT:     Info: 1
# CHECK-NEXT:     AddressAlignment: 8
# CHECK-NEXT:     EntrySize: 24

# CHECK:       Section {
# CHECK-NEXT:    Index: 2
# CHECK-NEXT:    Name: .gnu.version
# CHECK-NEXT:    Type: SHT_GNU_versym (0x6FFFFFFF)
# CHECK-NEXT:    Flags [ (0x2)
# CHECK-NEXT:      SHF_ALLOC (0x2)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: [[VERSYM:.*]]
# CHECK-NEXT:    Offset: [[VERSYM_OFFSET:.*]]
# CHECK-NEXT:    Size: 8
# CHECK-NEXT:    Link: 1
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 2
# CHECK-NEXT:    EntrySize: 2

# CHECK:       Section {
# CHECK-NEXT:    Index: 3
# CHECK-NEXT:    Name: .gnu.version_r
# CHECK-NEXT:    Type: SHT_GNU_verneed (0x6FFFFFFE)
# CHECK-NEXT:    Flags [ (0x2)
# CHECK-NEXT:      SHF_ALLOC (0x2)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: [[VERNEED:.*]]
# CHECK-NEXT:    Offset: 0x268
# CHECK-NEXT:    Size: 80
# CHECK-NEXT:    Link: 5
# CHECK-NEXT:    Info: 2
# CHECK-NEXT:    AddressAlignment: 4
# CHECK-NEXT:    EntrySize: 0

# CHECK:          Index: [[DYNSTR]]
# CHECK-NEXT:     Name: .dynstr
# CHECK-NEXT:     Type: SHT_STRTAB (0x3)
# CHECK-NEXT:     Flags [ (0x2)
# CHECK-NEXT:       SHF_ALLOC (0x2)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x2002E0
# CHECK-NEXT:     Offset: 0x2E0
# CHECK-NEXT:     Size: 47
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:     SectionData (
# CHECK-NEXT:       0000: 00663100 66320067 31007665 726E6565  |.f1.f2.g1.vernee|
# CHECK-NEXT:       0010: 64312E73 6F2E3000 76320076 33007665  |d1.so.0.v2.v3.ve|
# CHECK-NEXT:       0020: 726E6565 64322E73 6F2E3000 763100    |rneed2.so.0.v1.|
# CHECK-NEXT:     )
# CHECK-NEXT:   }

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local (0x0)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: f1@v3
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: f2@v2
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: g1@v1
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK:      0x000000006FFFFFF0 VERSYM               [[VERSYM]]
# CHECK-NEXT: 0x000000006FFFFFFE VERNEED              [[VERNEED]]
# CHECK-NEXT: 0x000000006FFFFFFF VERNEEDNUM           2

# CHECK:      Version symbols {
# CHECK-NEXT:    Section Name: .gnu.version
# CHECK-NEXT:    Address: [[VERSYM]]
# CHECK-NEXT:    Offset: [[VERSYM_OFFSET]]
# CHECK-NEXT:    Link: 1
# CHECK-NEXT:    Symbols [
# CHECK-NEXT:      Symbol {
# CHECK-NEXT:        Version: 0
# CHECK-NEXT:        Name:
# CHECK-NEXT:      }
# CHECK-NEXT:      Symbol {
# CHECK-NEXT:        Version: 2
# CHECK-NEXT:        Name: f1@v3
# CHECK-NEXT:      }
# CHECK-NEXT:      Symbol {
# CHECK-NEXT:        Version: 3
# CHECK-NEXT:        Name: f2@v2
# CHECK-NEXT:      }
# CHECK-NEXT:      Symbol {
# CHECK-NEXT:        Version: 4
# CHECK-NEXT:        Name: g1@v1
# CHECK-NEXT:      }
# CHECK-NEXT:    ]
# CHECK-NEXT:  }
# CHECK-NEXT:  SHT_GNU_verdef {
# CHECK-NEXT:  }
# CHECK-NEXT:  SHT_GNU_verneed {
# CHECK-NEXT:    Dependency {
# CHECK-NEXT:      Version: 1
# CHECK-NEXT:      Count: 2
# CHECK-NEXT:      FileName: verneed1.so.0
# CHECK-NEXT:      Entries [
# CHECK-NEXT:        Entry {
# CHECK-NEXT:          Hash: 1938
# CHECK-NEXT:          Flags: 0x0
# CHECK-NEXT:          Index: 3
# CHECK-NEXT:          Name: v2
# CHECK-NEXT:        }
# CHECK-NEXT:        Entry {
# CHECK-NEXT:          Hash: 1939
# CHECK-NEXT:          Flags: 0x0
# CHECK-NEXT:          Index: 2
# CHECK-NEXT:          Name: v3
# CHECK-NEXT:        }
# CHECK-NEXT:      ]
# CHECK-NEXT:    }
# CHECK-NEXT:    Dependency {
# CHECK-NEXT:      Version: 1
# CHECK-NEXT:      Count: 1
# CHECK-NEXT:      FileName: verneed2.so.0
# CHECK-NEXT:      Entries [
# CHECK-NEXT:        Entry {
# CHECK-NEXT:          Hash: 1937
# CHECK-NEXT:          Flags: 0x0
# CHECK-NEXT:          Index: 4
# CHECK-NEXT:          Name: v1
# CHECK-NEXT:        }
# CHECK-NEXT:      ]
# CHECK-NEXT:    }
# CHECK-NEXT:  }

.globl _start
_start:
call f1@plt
call f2@plt
call g1@plt
