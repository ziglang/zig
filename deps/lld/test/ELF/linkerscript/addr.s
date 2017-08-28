# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  . = 0x1000; \
# RUN:  .text  : { *(.text*) } \
# RUN: .foo.1 : { *(.foo.1) }  \
# RUN: .foo.2 ADDR(.foo.1) + 0x100 : { *(.foo.2) } \
# RUN: .foo.3 : { *(.foo.3) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t1
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address          Type
# CHECK-NEXT:   0               00000000 0000000000000000
# CHECK-NEXT:   1 .text         00000000 0000000000001000 TEXT DATA
# CHECK-NEXT:   2 .foo.1        00000008 0000000000001000 DATA
# CHECK-NEXT:   3 .foo.2        00000008 0000000000001100 DATA
# CHECK-NEXT:   4 .foo.3        00000008 0000000000001108 DATA

.text
.globl _start
_start:

.section .foo.1,"a"
 .quad 1

.section .foo.2,"a"
 .quad 2

.section .foo.3,"a"
 .quad 3
