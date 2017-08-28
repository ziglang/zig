# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tfile1.o

# RUN: echo "SECTIONS { .abc : { *(SORT(.foo.*) .bar.*) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %tfile1.o
# RUN: llvm-objdump -s %t1 | FileCheck %s

# CHECK:  Contents of section .abc:
# CHECK:   01000000 00000000 02000000 00000000
# CHECK:   03000000 00000000 04000000 00000000
# CHECK:   06000000 00000000 05000000 00000000

# RUN: echo "SECTIONS { \
# RUN:   .abc : { *(SORT(.foo.* EXCLUDE_FILE (*file1.o) .bar.*) .bar.*) } \
# RUN:  }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %tfile1.o
# RUN: llvm-objdump -s %t2 | FileCheck %s

.text
.globl _start
_start:

.section .foo.2,"a"
 .quad 2

.section .foo.3,"a"
 .quad 3

.section .foo.1,"a"
 .quad 1

.section .bar.4,"a"
 .quad 4

.section .bar.6,"a"
 .quad 6

.section .bar.5,"a"
 .quad 5
