# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "PHDRS { foobar PT_LOAD FILEHDR PHDRS; } \
# RUN:       SECTIONS {  . = 0x1000;  .abc : { *(.zed) } : foobar }" > %t.script
# RUN: ld.lld --script %t.script %t.o -o %t
# RUN: llvm-readelf -l -S -W %t | FileCheck %s

.section .zed, "a"
.zero 4


# CHECK: [ 1] .abc              PROGBITS        0000000000001000 001000 000004 00   A  0   0  1
# CHECK: LOAD           0x000000 0x0000000000000000 0x0000000000000000 0x001004 0x001004 R E 0x1000
