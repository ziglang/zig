# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --gc-sections
# RUN: llvm-readelf -S %t | FileCheck %s

# CHECK:  .merge1     PROGBITS    {{[0-9a-z]*}} {{[0-9a-z]*}} 000004

        .global _start
_start:
        .quad .Lfoo

        .section        .merge1,"aM",@progbits,4
        .p2align        2
.Lfoo:
        .long 1
.Lbar:
        .long 2

        .section        .merge2,"aM",@progbits,4
        .p2align        2
.Lzed:
        .long 1

        .section bar
        .quad .Lbar
	.quad .Lzed
