// REQUIRES: arm, aarch64

// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-shared.s -o %t.a32.so.o
// RUN: ld.lld -shared %t.a32.so.o -o %t.a32.so
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.a32
// RUN: ld.lld -pie --pack-dyn-relocs=none %t.a32 %t.a32.so -o %t2.a32
// RUN: llvm-readobj -r %t2.a32 | FileCheck --check-prefix=UNPACKED32 %s

// Unpacked should have the relative relocations in their natural order.
// UNPACKED32:          Section ({{.+}}) .rel.dyn {
// UNPACKED32-NEXT:     0x2000 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2004 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2008 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x200C R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2010 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2014 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2018 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x201C R_ARM_RELATIVE - 0x0

// UNPACKED32-NEXT:     0x2024 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2028 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x202C R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2030 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2034 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2038 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x203C R_ARM_RELATIVE - 0x0

// UNPACKED32-NEXT:     0x2044 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2048 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x204C R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2050 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2054 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2058 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x205C R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2060 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2064 R_ARM_RELATIVE - 0x0

// UNPACKED32-NEXT:     0x2069 R_ARM_RELATIVE - 0x0
// UNPACKED32-NEXT:     0x2020 R_ARM_ABS32 bar2 0x0
// UNPACKED32-NEXT:     0x2040 R_ARM_ABS32 zed2 0x0
// UNPACKED32-NEXT:     }

// RUN: ld.lld -pie --pack-dyn-relocs=android %t.a32 %t.a32.so -o %t3.a32
// RUN: llvm-readobj -S --dynamic-table %t3.a32 | FileCheck --check-prefix=ANDROID32-HEADERS %s
// RUN: llvm-readobj -r %t3.a32 | FileCheck --check-prefix=ANDROID32 %s

// ANDROID32-HEADERS:       Index: 1
// ANDROID32-HEADERS-NEXT:  Name: .dynsym

// ANDROID32-HEADERS:       Name: .rel.dyn
// ANDROID32-HEADERS-NEXT:  Type: SHT_ANDROID_REL
// ANDROID32-HEADERS-NEXT:  Flags [ (0x2)
// ANDROID32-HEADERS-NEXT:    SHF_ALLOC (0x2)
// ANDROID32-HEADERS-NEXT:  ]
// ANDROID32-HEADERS-NEXT:  Address: [[ADDR:.*]]
// ANDROID32-HEADERS-NEXT:  Offset: [[ADDR]]
// ANDROID32-HEADERS-NEXT:  Size: [[SIZE:.*]]
// ANDROID32-HEADERS-NEXT:  Link: 1
// ANDROID32-HEADERS-NEXT:  Info: 0
// ANDROID32-HEADERS-NEXT:  AddressAlignment: 4
// ANDROID32-HEADERS-NEXT:  EntrySize: 1

// ANDROID32-HEADERS: 0x6000000F ANDROID_REL          [[ADDR]]
// ANDROID32-HEADERS: 0x60000010 ANDROID_RELSZ        [[SIZE]]

// Packed should have the larger groups of relative relocations first,
// i.e. the 8 and 9 followed by the 7.
// ANDROID32:          Section ({{.+}}) .rel.dyn {
// ANDROID32-NEXT:     0x2000 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2004 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2008 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x200C R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2010 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2014 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2018 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x201C R_ARM_RELATIVE - 0x0

// ANDROID32-NEXT:     0x2044 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2048 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x204C R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2050 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2054 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2058 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x205C R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2060 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2064 R_ARM_RELATIVE - 0x0

// ANDROID32-NEXT:     0x2024 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2028 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x202C R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2030 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2034 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2038 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x203C R_ARM_RELATIVE - 0x0

// ANDROID32-NEXT:     0x2069 R_ARM_RELATIVE - 0x0
// ANDROID32-NEXT:     0x2020 R_ARM_ABS32 bar2 0x0
// ANDROID32-NEXT:     0x2040 R_ARM_ABS32 zed2 0x0
// ANDROID32-NEXT:     }

// RUN: ld.lld -pie --pack-dyn-relocs=relr %t.a32 %t.a32.so -o %t4.a32
// RUN: llvm-readobj -S --dynamic-table %t4.a32 | FileCheck --check-prefix=RELR32-HEADERS %s
// RUN: llvm-readobj -r --raw-relr %t4.a32 | FileCheck --check-prefix=RAW-RELR32 %s
// RUN: llvm-readobj -r %t4.a32 | FileCheck --check-prefix=RELR32 %s

// RELR32-HEADERS:       Index: 1
// RELR32-HEADERS-NEXT:  Name: .dynsym

// RELR32-HEADERS:       Name: .relr.dyn
// RELR32-HEADERS-NEXT:  Type: SHT_RELR
// RELR32-HEADERS-NEXT:  Flags [ (0x2)
// RELR32-HEADERS-NEXT:    SHF_ALLOC (0x2)
// RELR32-HEADERS-NEXT:  ]
// RELR32-HEADERS-NEXT:  Address: [[ADDR:.*]]
// RELR32-HEADERS-NEXT:  Offset: [[ADDR]]
// RELR32-HEADERS-NEXT:  Size: 8
// RELR32-HEADERS-NEXT:  Link: 0
// RELR32-HEADERS-NEXT:  Info: 0
// RELR32-HEADERS-NEXT:  AddressAlignment: 4
// RELR32-HEADERS-NEXT:  EntrySize: 4

// RELR32-HEADERS:       0x00000024 RELR                 [[ADDR]]
// RELR32-HEADERS:       0x00000023 RELRSZ               0x8
// RELR32-HEADERS:       0x00000025 RELRENT              0x4

// SHT_RELR section contains address/bitmap entries
// encoding the offsets for relative relocation.
// RAW-RELR32:           Section ({{.+}}) .relr.dyn {
// RAW-RELR32-NEXT:      0x2000
// RAW-RELR32-NEXT:      0x3FEFEFF
// RAW-RELR32-NEXT:      }

// Decoded SHT_RELR section is same as UNPACKED,
// but contains only the relative relocations.
// Any relative relocations with odd offset stay in SHT_REL.
// RELR32:               Section ({{.+}}) .rel.dyn {
// RELR32-NEXT:          0x2069 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2020 R_ARM_ABS32 bar2 0x0
// RELR32-NEXT:          0x2040 R_ARM_ABS32 zed2 0x0
// RELR32-NEXT:          }
// RELR32-NEXT:          Section ({{.+}}) .relr.dyn {
// RELR32-NEXT:          0x2000 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2004 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2008 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x200C R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2010 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2014 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2018 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x201C R_ARM_RELATIVE - 0x0

// RELR32-NEXT:          0x2024 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2028 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x202C R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2030 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2034 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2038 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x203C R_ARM_RELATIVE - 0x0

// RELR32-NEXT:          0x2044 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2048 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x204C R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2050 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2054 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2058 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x205C R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2060 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          0x2064 R_ARM_RELATIVE - 0x0
// RELR32-NEXT:          }

// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %p/Inputs/shared2.s -o %t.a64.so.o
// RUN: ld.lld -shared %t.a64.so.o -o %t.a64.so
// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.a64
// RUN: ld.lld -pie --pack-dyn-relocs=none %t.a64 %t.a64.so -o %t2.a64
// RUN: llvm-readobj -r %t2.a64 | FileCheck --check-prefix=UNPACKED64 %s

// UNPACKED64:          Section ({{.+}}) .rela.dyn {
// UNPACKED64-NEXT:     0x20000 R_AARCH64_RELATIVE - 0x1
// UNPACKED64-NEXT:     0x20008 R_AARCH64_RELATIVE - 0x2
// UNPACKED64-NEXT:     0x20010 R_AARCH64_RELATIVE - 0x3
// UNPACKED64-NEXT:     0x20018 R_AARCH64_RELATIVE - 0x4
// UNPACKED64-NEXT:     0x20020 R_AARCH64_RELATIVE - 0x5
// UNPACKED64-NEXT:     0x20028 R_AARCH64_RELATIVE - 0x6
// UNPACKED64-NEXT:     0x20030 R_AARCH64_RELATIVE - 0x7
// UNPACKED64-NEXT:     0x20038 R_AARCH64_RELATIVE - 0x8

// UNPACKED64-NEXT:     0x20048 R_AARCH64_RELATIVE - 0x1
// UNPACKED64-NEXT:     0x20050 R_AARCH64_RELATIVE - 0x2
// UNPACKED64-NEXT:     0x20058 R_AARCH64_RELATIVE - 0x3
// UNPACKED64-NEXT:     0x20060 R_AARCH64_RELATIVE - 0x4
// UNPACKED64-NEXT:     0x20068 R_AARCH64_RELATIVE - 0x5
// UNPACKED64-NEXT:     0x20070 R_AARCH64_RELATIVE - 0x6
// UNPACKED64-NEXT:     0x20078 R_AARCH64_RELATIVE - 0x7

// UNPACKED64-NEXT:     0x20088 R_AARCH64_RELATIVE - 0x1
// UNPACKED64-NEXT:     0x20090 R_AARCH64_RELATIVE - 0x2
// UNPACKED64-NEXT:     0x20098 R_AARCH64_RELATIVE - 0x3
// UNPACKED64-NEXT:     0x200A0 R_AARCH64_RELATIVE - 0x4
// UNPACKED64-NEXT:     0x200A8 R_AARCH64_RELATIVE - 0x5
// UNPACKED64-NEXT:     0x200B0 R_AARCH64_RELATIVE - 0x6
// UNPACKED64-NEXT:     0x200B8 R_AARCH64_RELATIVE - 0x7
// UNPACKED64-NEXT:     0x200C0 R_AARCH64_RELATIVE - 0x8
// UNPACKED64-NEXT:     0x200C8 R_AARCH64_RELATIVE - 0x9

// UNPACKED64-NEXT:     0x200D1 R_AARCH64_RELATIVE - 0xA
// UNPACKED64-NEXT:     0x20040 R_AARCH64_ABS64 bar2 0x1
// UNPACKED64-NEXT:     0x20080 R_AARCH64_ABS64 zed2 0x0
// UNPACKED64-NEXT:     }

// RUN: ld.lld -pie --pack-dyn-relocs=android %t.a64 %t.a64.so -o %t3.a64
// RUN: llvm-readobj -S --dynamic-table %t3.a64 | FileCheck --check-prefix=ANDROID64-HEADERS %s
// RUN: llvm-readobj -r %t3.a64 | FileCheck --check-prefix=ANDROID64 %s

// ANDROID64-HEADERS:       Index: 1
// ANDROID64-HEADERS-NEXT:  Name: .dynsym

// ANDROID64-HEADERS:       Name: .rela.dyn
// ANDROID64-HEADERS-NEXT:  Type: SHT_ANDROID_RELA
// ANDROID64-HEADERS-NEXT:  Flags [ (0x2)
// ANDROID64-HEADERS-NEXT:    SHF_ALLOC (0x2)
// ANDROID64-HEADERS-NEXT:  ]
// ANDROID64-HEADERS-NEXT:  Address: [[ADDR:.*]]
// ANDROID64-HEADERS-NEXT:  Offset: [[ADDR]]
// ANDROID64-HEADERS-NEXT:  Size: [[SIZE:.*]]
// ANDROID64-HEADERS-NEXT:  Link: 1
// ANDROID64-HEADERS-NEXT:  Info: 0
// ANDROID64-HEADERS-NEXT:  AddressAlignment: 8
// ANDROID64-HEADERS-NEXT:  EntrySize: 1

// ANDROID64-HEADERS: 0x0000000060000011 ANDROID_RELA          [[ADDR]]
// ANDROID64-HEADERS: 0x0000000060000012 ANDROID_RELASZ        [[SIZE]]

// ANDROID64:          Section ({{.+}}) .rela.dyn {
// ANDROID64-NEXT:     0x20000 R_AARCH64_RELATIVE - 0x1
// ANDROID64-NEXT:     0x20008 R_AARCH64_RELATIVE - 0x2
// ANDROID64-NEXT:     0x20010 R_AARCH64_RELATIVE - 0x3
// ANDROID64-NEXT:     0x20018 R_AARCH64_RELATIVE - 0x4
// ANDROID64-NEXT:     0x20020 R_AARCH64_RELATIVE - 0x5
// ANDROID64-NEXT:     0x20028 R_AARCH64_RELATIVE - 0x6
// ANDROID64-NEXT:     0x20030 R_AARCH64_RELATIVE - 0x7
// ANDROID64-NEXT:     0x20038 R_AARCH64_RELATIVE - 0x8

// ANDROID64-NEXT:     0x20088 R_AARCH64_RELATIVE - 0x1
// ANDROID64-NEXT:     0x20090 R_AARCH64_RELATIVE - 0x2
// ANDROID64-NEXT:     0x20098 R_AARCH64_RELATIVE - 0x3
// ANDROID64-NEXT:     0x200A0 R_AARCH64_RELATIVE - 0x4
// ANDROID64-NEXT:     0x200A8 R_AARCH64_RELATIVE - 0x5
// ANDROID64-NEXT:     0x200B0 R_AARCH64_RELATIVE - 0x6
// ANDROID64-NEXT:     0x200B8 R_AARCH64_RELATIVE - 0x7
// ANDROID64-NEXT:     0x200C0 R_AARCH64_RELATIVE - 0x8
// ANDROID64-NEXT:     0x200C8 R_AARCH64_RELATIVE - 0x9

// ANDROID64-NEXT:     0x20048 R_AARCH64_RELATIVE - 0x1
// ANDROID64-NEXT:     0x20050 R_AARCH64_RELATIVE - 0x2
// ANDROID64-NEXT:     0x20058 R_AARCH64_RELATIVE - 0x3
// ANDROID64-NEXT:     0x20060 R_AARCH64_RELATIVE - 0x4
// ANDROID64-NEXT:     0x20068 R_AARCH64_RELATIVE - 0x5
// ANDROID64-NEXT:     0x20070 R_AARCH64_RELATIVE - 0x6
// ANDROID64-NEXT:     0x20078 R_AARCH64_RELATIVE - 0x7

// ANDROID64-NEXT:     0x200D1 R_AARCH64_RELATIVE - 0xA
// ANDROID64-NEXT:     0x20040 R_AARCH64_ABS64 bar2 0x1
// ANDROID64-NEXT:     0x20080 R_AARCH64_ABS64 zed2 0x0
// ANDROID64-NEXT:     }

// RUN: ld.lld -pie --pack-dyn-relocs=relr %t.a64 %t.a64.so -o %t4.a64
// RUN: llvm-readobj -S --dynamic-table %t4.a64 | FileCheck --check-prefix=RELR64-HEADERS %s
// RUN: llvm-readobj -r --raw-relr %t4.a64 | FileCheck --check-prefix=RAW-RELR64 %s
// RUN: llvm-readobj -r %t4.a64 | FileCheck --check-prefix=RELR64 %s

// RELR64-HEADERS:       Index: 1
// RELR64-HEADERS-NEXT:  Name: .dynsym

// RELR64-HEADERS:       Name: .relr.dyn
// RELR64-HEADERS-NEXT:  Type: SHT_RELR
// RELR64-HEADERS-NEXT:  Flags [ (0x2)
// RELR64-HEADERS-NEXT:    SHF_ALLOC (0x2)
// RELR64-HEADERS-NEXT:  ]
// RELR64-HEADERS-NEXT:  Address: [[ADDR:.*]]
// RELR64-HEADERS-NEXT:  Offset: [[ADDR]]
// RELR64-HEADERS-NEXT:  Size: 16
// RELR64-HEADERS-NEXT:  Link: 0
// RELR64-HEADERS-NEXT:  Info: 0
// RELR64-HEADERS-NEXT:  AddressAlignment: 8
// RELR64-HEADERS-NEXT:  EntrySize: 8

// RELR64-HEADERS:       0x0000000000000024 RELR                 [[ADDR]]
// RELR64-HEADERS:       0x0000000000000023 RELRSZ               0x10
// RELR64-HEADERS:       0x0000000000000025 RELRENT              0x8

// SHT_RELR section contains address/bitmap entries
// encoding the offsets for relative relocation.
// RAW-RELR64:           Section ({{.+}}) .relr.dyn {
// RAW-RELR64-NEXT:      0x20000
// RAW-RELR64-NEXT:      0x3FEFEFF
// RAW-RELR64-NEXT:      }

// Decoded SHT_RELR section is same as UNPACKED,
// but contains only the relative relocations.
// Any relative relocations with odd offset stay in SHT_RELA.
// RELR64:               Section ({{.+}}) .rela.dyn {
// RELR64-NEXT:          0x200D1 R_AARCH64_RELATIVE - 0xA
// RELR64-NEXT:          0x20040 R_AARCH64_ABS64 bar2 0x1
// RELR64-NEXT:          0x20080 R_AARCH64_ABS64 zed2 0x0
// RELR64-NEXT:          }
// RELR64-NEXT:          Section ({{.+}}) .relr.dyn {
// RELR64-NEXT:          0x20000 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20008 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20010 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20018 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20020 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20028 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20030 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20038 R_AARCH64_RELATIVE - 0x0

// RELR64-NEXT:          0x20048 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20050 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20058 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20060 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20068 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20070 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20078 R_AARCH64_RELATIVE - 0x0

// RELR64-NEXT:          0x20088 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20090 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x20098 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200A0 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200A8 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200B0 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200B8 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200C0 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          0x200C8 R_AARCH64_RELATIVE - 0x0
// RELR64-NEXT:          }

.data
.align 2
.dc.a __ehdr_start + 1
.dc.a __ehdr_start + 2
.dc.a __ehdr_start + 3
.dc.a __ehdr_start + 4
.dc.a __ehdr_start + 5
.dc.a __ehdr_start + 6
.dc.a __ehdr_start + 7
.dc.a __ehdr_start + 8
.dc.a bar2 + 1

.dc.a __ehdr_start + 1
.dc.a __ehdr_start + 2
.dc.a __ehdr_start + 3
.dc.a __ehdr_start + 4
.dc.a __ehdr_start + 5
.dc.a __ehdr_start + 6
.dc.a __ehdr_start + 7
.dc.a zed2

.dc.a __ehdr_start + 1
.dc.a __ehdr_start + 2
.dc.a __ehdr_start + 3
.dc.a __ehdr_start + 4
.dc.a __ehdr_start + 5
.dc.a __ehdr_start + 6
.dc.a __ehdr_start + 7
.dc.a __ehdr_start + 8
.dc.a __ehdr_start + 9
.byte 00
.dc.a __ehdr_start + 10
