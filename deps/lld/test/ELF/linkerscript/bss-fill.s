# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .bss : { . += 0x10000; *(.bss) } =0xFF };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o

.section .bss,"",@nobits
.short 0
