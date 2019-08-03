// Test that notes (both from object files and synthetic) are duplicated into
// each partition.

// REQUIRES: x86

// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=x86_64-unknown-linux
// RUN: ld.lld %t.o -o %t --shared --gc-sections --build-id=sha1

// RUN: llvm-objcopy --extract-main-partition %t %t0
// RUN: llvm-objcopy --extract-partition=part1 %t %t1

// RUN: llvm-readelf --all %t0 | FileCheck --check-prefixes=CHECK,PART0 %s
// RUN: llvm-readelf --all %t1 | FileCheck --check-prefixes=CHECK,PART1 %s

// CHECK: Program Headers:
// CHECK: NOTE 0x{{0*}}[[NOTE_OFFSET:[^ ]*]]

// CHECK: Displaying notes found at file offset 0x{{0*}}[[NOTE_OFFSET]]
// CHECK-NEXT: Owner
// CHECK-NEXT: foo                   0x00000004	NT_VERSION (version)
// CHECK-NEXT: Displaying notes
// CHECK-NEXT: Owner
// CHECK-NEXT: GNU                   0x00000014	NT_GNU_BUILD_ID (unique build ID bitstring)
// CHECK-NEXT: Build ID: 0f4d5297cbbe52e4bea558eeb792944670de22e1

.section .llvm_sympart,"",@llvm_sympart
.asciz "part1"
.quad p1

.section .data.p0,"aw",@progbits
.globl p0
p0:

.section .data.p1,"aw",@progbits
.globl p1
p1:

.section .note.obj,"a",@note
.align 4
.long 2f-1f
.long 3f-2f
.long 1
1: .asciz "foo"
2: .asciz "bar"
3:
