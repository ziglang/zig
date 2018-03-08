# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --export-dynamic
# RUN: llvm-readobj -r %t | FileCheck %s

# CHECK: R_X86_64_64 foobar 0x0

        .global _start
_start:
        .data
        .weak foobar
        .quad foobar
