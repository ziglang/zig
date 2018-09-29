# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple x86_64-pc-linux-gnu %s -o %t
# RUN: ld.lld --icf=all --print-icf-sections %t -o /dev/null | FileCheck %s -allow-empty

# CHECK-NOT: selected

.macro gen_sections4 z
        .section .a\z,"ax"
        .section .b\z,"ax"
        .section .c\z,"ax"
        .section .d\z,"ax"
.endm

.macro gen_sections8 z
        gen_sections4 a\z
        gen_sections4 b\z
.endm

.macro gen_sections16 z
        gen_sections8 a\z
        gen_sections8 b\z
.endm

.macro gen_sections32 x
        gen_sections16 a\x
        gen_sections16 b\x
.endm

.macro gen_sections64 z
        gen_sections32 a\z
        gen_sections32 b\z
.endm

.macro gen_sections128 z
        gen_sections64 a\z
        gen_sections64 b\z
.endm

.macro gen_sections256 z
        gen_sections128 a\z
        gen_sections128 b\z
.endm

.macro gen_sections512 z
        gen_sections256 a\z
        gen_sections256 b\z
.endm

.macro gen_sections1024 z
        gen_sections512 a\z
        gen_sections512 b\z
.endm

.macro gen_sections2048 z
        gen_sections1024 a\z
        gen_sections1024 b\z
.endm

gen_sections2048 a

.global _start
_start:
