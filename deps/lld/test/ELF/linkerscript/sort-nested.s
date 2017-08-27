# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/sort-nested.s -o %t2.o

## Check sorting first by alignment and then by name.
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.aaa.*))) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t1.o %t2.o
# RUN: llvm-objdump -s %t1 | FileCheck -check-prefix=SORTED_AN %s
# SORTED_AN:      Contents of section .aaa:
# SORTED_AN-NEXT:   01000000 00000000 00000000 00000000
# SORTED_AN-NEXT:   11000000 00000000 00000000 00000000
# SORTED_AN-NEXT:   55000000 00000000 22000000 00000000
# SORTED_AN-NEXT:   02000000 00000000

## Check sorting first by name and then by alignment.
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_NAME(SORT_BY_ALIGNMENT(.aaa.*))) } }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t1.o %t2.o
# RUN: llvm-objdump -s %t2 | FileCheck -check-prefix=SORTED_NA %s
# SORTED_NA: Contents of section .aaa:
# SORTED_NA:   01000000 00000000 00000000 00000000
# SORTED_NA:   11000000 00000000 22000000 00000000
# SORTED_NA:   02000000 00000000 00000000 00000000
# SORTED_NA:   55000000 00000000

## If the section sorting command in linker script isn't nested, the
## command line option will make the section sorting command to be treated
## as nested sorting command.
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_ALIGNMENT(.aaa.*)) } }" > %t3.script
# RUN: ld.lld --sort-section name -o %t3 --script %t3.script %t1.o %t2.o
# RUN: llvm-objdump -s %t3 | FileCheck -check-prefix=SORTED_AN %s
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_NAME(.aaa.*)) } }" > %t4.script
# RUN: ld.lld --sort-section alignment -o %t4 --script %t4.script %t1.o %t2.o
# RUN: llvm-objdump -s %t4 | FileCheck -check-prefix=SORTED_NA %s

.global _start
_start:
 nop

.section .aaa.1, "a"
.align 32
.quad 1

.section .aaa.2, "a"
.align 2
.quad 2

.section .aaa.5, "a"
.align 16
.quad 0x55
