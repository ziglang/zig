# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -l %t | FileCheck %s

# Check that we don't mix 4-byte and 8-byte aligned notes in one PT_LOAD.
# The possible 4-byte padding before the 8-byte align note may make consumers
# fail to parse it.

# CHECK: NOTE {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} 0x000004 0x000004 R   0x4
# CHECK: NOTE {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} 0x000010 0x000010 R   0x8
# CHECK: NOTE {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} {{0x[0-9a-f]+}} 0x000008 0x000008 R   0x4

# CHECK:      03     .note.a
# CHECK-NEXT: 04     .note.b .note.c
# CHECK-NEXT: 05     .note.d .note.e

.section .note.a, "a", @note
.align 4
.long 0

.section .note.b, "a", @note
.align 8
.quad 0

.section .note.c, "a", @note
.align 8
.quad 0

.section .note.d, "a", @note
.align 4
.long 0

.section .note.e, "a", @note
.align 4
.long 0
