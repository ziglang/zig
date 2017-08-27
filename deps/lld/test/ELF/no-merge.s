# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .rodata : {*(.rodata.*)} }" > %t0.script
# RUN: ld.lld %t.o -o %t0.out --script %t0.script
# RUN: llvm-objdump -s %t0.out | FileCheck %s

# RUN: ld.lld -O0 %t.o -o %t1.out --script %t0.script
# RUN: llvm-objdump -s %t1.out | FileCheck %s
# CHECK:      Contents of section .rodata:
# CHECK-NEXT:   0000 01610003

.section .rodata.a,"a",@progbits
.byte 1

.section .rodata.ams,"aMS",@progbits,1
.asciz "a"

.section .rodata.am,"aM",@progbits,1
.byte 3
