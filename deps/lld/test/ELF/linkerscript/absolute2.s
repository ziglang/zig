# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { .text : { *(.text) } foo = ABSOLUTE(_start) + _start; };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -t %t | FileCheck %s

# RUN: echo "SECTIONS { .text : { *(.text) } foo = _start + ABSOLUTE(_start); };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -t %t | FileCheck %s

# CHECK: 0000000000000001         .text           00000000 _start
# CHECK: 0000000000000002         .text           00000000 foo

        .global _start
        nop
_start:
