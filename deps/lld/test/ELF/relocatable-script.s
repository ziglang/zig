# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -o %t1.o %s
# RUN: echo "SECTIONS { .foo : { BYTE(0x0) } }" > %t.script
# RUN: ld.lld -r %t1.o -script %t.script -o %t2.o
# RUN: llvm-readobj --sections %t2.o | FileCheck %s

# CHECK:  Name: .foo
