// REQUIRES: arm, aarch64

// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-android %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so --pack-dyn-relocs=android
// RUN: llvm-readobj -s %t.so | FileCheck %s

// This test is making sure the Android packed relocation support doesn't
// cause an infinite loop due to the size of the section oscillating
// (because the size of the section impacts the layout of the following
// sections).

// This test is very sensitive to the exact section sizes and offsets,
// so check that they don't change.
// CHECK:         Name: .rela.dyn (33)
// CHECK-NEXT:    Type: SHT_ANDROID_RELA (0x60000002)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x210
// CHECK-NEXT:    Offset: 0x210
// CHECK-NEXT:    Size: 21

// CHECK:         Name: x (43)
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x225
// CHECK-NEXT:    Offset: 0x225
// CHECK-NEXT:    Size: 64980

// CHECK:         Name: barr (45)
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [ (0x2)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0xFFFA
// CHECK-NEXT:    Offset: 0xFFFA
// CHECK-NEXT:    Size: 0

// CHECK:         Name: foo (62)
// CHECK-NEXT:    Type: SHT_PROGBITS (0x1)
// CHECK-NEXT:    Flags [ (0x3)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_WRITE (0x1)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address: 0x10004
// CHECK-NEXT:    Offset: 0x10004
// CHECK-NEXT:    Size: 12


.data
.long 0

.section foo,"aw"
foof:
.long foof
.long bar-53
.long bar

.section x,"a"
.zero 64980

.section barr,"a"
.p2align 1
bar:
