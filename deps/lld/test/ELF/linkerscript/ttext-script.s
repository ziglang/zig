# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .text 0x200000 : { *(.text) } }" > %t.script
# RUN: ld.lld -T %t.script -Ttext 0x100000 %t.o -o %t
# RUN: llvm-readobj --elf-output-style=GNU -s  %t | FileCheck %s

# CHECK: .text             PROGBITS        0000000000100000

.global _start
_start:
nop
