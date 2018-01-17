# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .foo : ALIGN(2M) { *(.foo) } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o -shared
# RUN: llvm-readelf -S -l %t | FileCheck %s

# CHECK: .foo  PROGBITS  0000000000200000 200000 000008 00  WA  0   0 2097152
# CHECK: LOAD           0x200000 0x0000000000200000 0x0000000000200000 {{.*}} RW  0x200000

        .section .foo, "aw"
        .quad 42
