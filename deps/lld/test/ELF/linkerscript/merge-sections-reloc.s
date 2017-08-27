# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/merge-sections-reloc.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
# RUN: echo "SECTIONS {}" > %t.script
# RUN: ld.lld -o %t --script %t.script %t1.o %t2.o
# RUN: llvm-objdump -s %t | FileCheck %s

## Check that sections content is not corrupted.
# CHECK:      Contents of section .text:
# CHECK-NEXT:  44332211 00000000 44332211 00000000
# CHECK-NEXT:  f0ffffff ffffffff

.globl _start
_foo:
 .quad 0x11223344
 .quad _start - .
