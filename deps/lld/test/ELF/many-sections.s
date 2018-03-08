// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple x86_64-pc-linux-gnu %s -o %t
// RUN: llvm-readobj -t %t | FileCheck  %s

// Verify that the symbol _start is in a section with an index >= SHN_LORESERVE.
// CHECK:      Name: _start
// CHECK-NEXT: Value: 0x0
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: None
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: dm (0xFF00)

// RUN: ld.lld %t -o %t2
// RUN: llvm-readobj -t %t2 | FileCheck --check-prefix=LINKED %s

// Test also with a linker script.
// RUN: echo "SECTIONS { . = SIZEOF_HEADERS; .text : { *(.text) } }" > %t.script
// RUN: ld.lld -T %t.script %t -o %t2
// RUN: llvm-readobj -t %t2 | FileCheck --check-prefix=LINKED %s

// Test that _start is in the correct section.
// LINKED:      Name: _start
// LINKED-NEXT: Value: 0x0
// LINKED-NEXT: Size: 0
// LINKED-NEXT: Binding: Global
// LINKED-NEXT: Type: None
// LINKED-NEXT: Other: 0
// LINKED-NEXT: Section: dm

.macro gen_sections4 x
        .section a\x
        .section b\x
        .section c\x
        .section d\x
.endm

.macro gen_sections8 x
        gen_sections4 a\x
        gen_sections4 b\x
.endm

.macro gen_sections16 x
        gen_sections8 a\x
        gen_sections8 b\x
.endm

.macro gen_sections32 x
        gen_sections16 a\x
        gen_sections16 b\x
.endm

.macro gen_sections64 x
        gen_sections32 a\x
        gen_sections32 b\x
.endm

.macro gen_sections128 x
        gen_sections64 a\x
        gen_sections64 b\x
.endm

.macro gen_sections256 x
        gen_sections128 a\x
        gen_sections128 b\x
.endm

.macro gen_sections512 x
        gen_sections256 a\x
        gen_sections256 b\x
.endm

.macro gen_sections1024 x
        gen_sections512 a\x
        gen_sections512 b\x
.endm

.macro gen_sections2048 x
        gen_sections1024 a\x
        gen_sections1024 b\x
.endm

.macro gen_sections4096 x
        gen_sections2048 a\x
        gen_sections2048 b\x
.endm

.macro gen_sections8192 x
        gen_sections4096 a\x
        gen_sections4096 b\x
.endm

.macro gen_sections16384 x
        gen_sections8192 a\x
        gen_sections8192 b\x
.endm

.macro gen_sections32768 x
        gen_sections16384 a\x
        gen_sections16384 b\x
.endm

        .bss
        .section bar

gen_sections32768 a
gen_sections16384 b
gen_sections8192 c
gen_sections4096 d
gen_sections2048 e
gen_sections1024 f
gen_sections512 g
gen_sections128 h
gen_sections64 i
gen_sections32 j
gen_sections16 k
gen_sections8 l
gen_sections4 m

.global _start
_start:
