# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .foo : { *(.foo) } }" > %t.script

# RUN: ld.lld %t.o --script %t.script -o %t.out
# RUN: llvm-objdump -s %t.out| FileCheck %s --check-prefix=BEFORE
# BEFORE:      Contents of section .foo:
# BEFORE-NEXT: 1122

# RUN: echo "_foo2" > %t.ord
# RUN: echo "_foo1" >> %t.ord
# RUN: ld.lld --symbol-ordering-file %t.ord %t.o --script %t.script -o %t2.out
# RUN: llvm-objdump -s %t2.out| FileCheck %s --check-prefix=AFTER
# AFTER:      Contents of section .foo:
# AFTER-NEXT: 2211

.section .foo,"ax",@progbits,unique,1
_foo1:
 .byte 0x11

.section .foo,"ax",@progbits,unique,2
_foo2:
 .byte 0x22
