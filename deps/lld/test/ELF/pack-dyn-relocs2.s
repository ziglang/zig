// REQUIRES: arm, aarch64

// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-shared.s -o %t.so.o
// RUN: ld.lld -shared %t.so.o -o %t.so

// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -pie --pack-dyn-relocs=relr %t.o %t.so -o %t.exe
// RUN: llvm-readobj -r %t.exe | FileCheck %s

// CHECK:      Section (5) .relr.dyn {
// CHECK-NEXT:   0x2000 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2004 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2008 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x200C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2010 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2014 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2018 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x201C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2020 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2024 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2028 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x202C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2030 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2034 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2038 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x203C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2040 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2044 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2048 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x204C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2050 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2054 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2058 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x205C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2060 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2064 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2068 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x206C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2070 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2074 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2078 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x207C R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2080 R_ARM_RELATIVE - 0x0
// CHECK-NEXT:   0x2084 R_ARM_RELATIVE - 0x0
// CHECK-NEXT: }

// RUN: llvm-readobj -S --dynamic-table %t.exe | FileCheck --check-prefix=HEADER %s
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
