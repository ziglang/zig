// REQUIRES: arm, aarch64

// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-shared.s -o %t.so.o
// RUN: ld.lld -shared %t.so.o -o %t.so

// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -pie --pack-dyn-relocs=relr %t.o %t.so -o %t.exe
// RUN: llvm-readobj -relocations %t.exe | FileCheck %s

// CHECK:      Section (5) .relr.dyn {
// CHECK-NEXT:   0x1000 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1004 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1008 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x100C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1010 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1014 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1018 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x101C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1020 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1024 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1028 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x102C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1030 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1034 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1038 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x103C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1040 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1044 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1048 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x104C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1050 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1054 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1058 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x105C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1060 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1064 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1068 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x106C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1070 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1074 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1078 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x107C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1080 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x1084 R_ARM_RELATIVE - 0x0
// CHECK-NEXT: }

// RUN: llvm-readobj -s -dynamic-table %t.exe | FileCheck --check-prefix=HEADER %s
// HEADER: 0x00000023 RELRSZ 0xC

.data
.align 2
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
.dc.a __ehdr_start
