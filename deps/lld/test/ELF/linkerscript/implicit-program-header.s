# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv -o %t1 --script %S/Inputs/implicit-program-header.script  \
# RUN:   %t.o -shared
# RUN: llvm-readobj -elf-output-style=GNU -l %t1 | FileCheck %s

# CHECK:      Segment Sections...
# CHECK-NEXT:   00     .text .dynsym .hash .dynstr .dynamic
# CHECK-NEXT:   01     .foo

.quad 0
.section .foo,"ax"
.quad 0
