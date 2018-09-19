# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "PHDRS { foobar PT_LOAD FILEHDR PHDRS; }"  > %t.script
# RUN: echo "SECTIONS { .text : { *(.text) } : foobar }" >> %t.script
# RUN: not ld.lld --script %t.script %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: could not allocate headers

        .global _start
_start:
        retq
