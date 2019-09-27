// Test that both Android and RELR packed relocation sections are created
// correctly for each partition.

// REQUIRES: x86

// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=x86_64-unknown-linux
// RUN: ld.lld %t.o -o %t --shared --gc-sections --pack-dyn-relocs=android+relr

// RUN: llvm-objcopy --extract-main-partition %t %t0
// RUN: llvm-objcopy --extract-partition=part1 %t %t1

// RUN: llvm-readelf --all %t0 | FileCheck --check-prefixes=CHECK,PART0 %s
// RUN: llvm-readelf --all %t1 | FileCheck --check-prefixes=CHECK,PART1 %s

// CHECK: Section Headers:
// CHECK: .rela.dyn      ANDROID_RELA {{0*}}[[ANDROID_RELA_ADDR:[^ ]*]]
// CHECK: .relr.dyn      RELR         {{0*}}[[RELR_ADDR:[^ ]*]]
// CHECK: .data          PROGBITS     000000000000[[DATA_SEGMENT:.]]000

// CHECK: Relocation section '.rela.dyn'
// CHECK-NEXT: Offset
// PART0-NEXT: 000000000000[[DATA_SEGMENT]]008 {{.*}} R_X86_64_64 000000000000[[DATA_SEGMENT]]000 p0 + 0
// PART1-NEXT: 000000000000[[DATA_SEGMENT]]008 {{.*}} R_X86_64_64 000000000000[[DATA_SEGMENT]]000 p1 + 0
// CHECK-EMPTY:

// CHECK: Relocation section '.relr.dyn'
// CHECK-NEXT: Offset
// CHECK-NEXT: 000000000000[[DATA_SEGMENT]]000 {{.*}} R_X86_64_RELATIVE
// CHECK-EMPTY:

// CHECK: Dynamic section
// CHECK: 0x0000000060000011 (ANDROID_RELA)       0x[[ANDROID_RELA_ADDR]]
// CHECK: 0x0000000000000024 (RELR)               0x[[RELR_ADDR]]

.section .llvm_sympart,"",@llvm_sympart
.asciz "part1"
.quad p1

.section .data.p0,"aw",@progbits
.align 8
.globl p0
p0:
.quad __ehdr_start
.quad p0

.section .data.p1,"aw",@progbits
.align 8
.globl p1
p1:
.quad __ehdr_start
.quad p1
