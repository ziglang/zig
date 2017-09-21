# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/sort.s -o %t2.o

# RUN: echo "SECTIONS { .aaa : { *(.aaa.*) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t2.o %t1.o
# RUN: llvm-objdump -s %t1 | FileCheck -check-prefix=UNSORTED %s
# UNSORTED:       Contents of section .aaa:
# UNSORTED-NEXT:   55000000 00000000 00000000 00000000
# UNSORTED-NEXT:   00000000 00000000 00000000 00000000
# UNSORTED-NEXT:   11000000 00000000 33000000 00000000
# UNSORTED-NEXT:   22000000 00000000 44000000 00000000
# UNSORTED-NEXT:   05000000 00000000 01000000 00000000
# UNSORTED-NEXT:   03000000 00000000 02000000 00000000
# UNSORTED-NEXT:   04000000 00000000

## Check that SORT works (sorted by name of section).
# RUN: echo "SECTIONS { .aaa : { *(SORT(.aaa.*)) } }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t2.o %t1.o
# RUN: llvm-objdump -s %t2 | FileCheck -check-prefix=SORTED_A %s
# SORTED_A:      Contents of section .aaa:
# SORTED_A-NEXT:  11000000 00000000 01000000 00000000
# SORTED_A-NEXT:  22000000 00000000 02000000 00000000
# SORTED_A-NEXT:  33000000 00000000 03000000 00000000
# SORTED_A-NEXT:  44000000 00000000 00000000 00000000
# SORTED_A-NEXT:  04000000 00000000 55000000 00000000
# SORTED_A-NEXT:  00000000 00000000 00000000 00000000
# SORTED_A-NEXT:  05000000 00000000

## When we switch the order of files, check that sorting by
## section names is stable.
# RUN: echo "SECTIONS { .aaa : { *(SORT(.aaa.*)) } }" > %t3.script
# RUN: ld.lld -o %t3 --script %t3.script %t1.o %t2.o
# RUN: llvm-objdump -s %t3 | FileCheck -check-prefix=SORTED_B %s
# SORTED_B:      Contents of section .aaa:
# SORTED_B-NEXT:  01000000 00000000 00000000 00000000
# SORTED_B-NEXT:  00000000 00000000 00000000 00000000
# SORTED_B-NEXT:  11000000 00000000 02000000 00000000
# SORTED_B-NEXT:  22000000 00000000 03000000 00000000
# SORTED_B-NEXT:  33000000 00000000 00000000 00000000
# SORTED_B-NEXT:  04000000 00000000 44000000 00000000
# SORTED_B-NEXT:  05000000 00000000 55000000 00000000

## Check that SORT surrounded with KEEP also works.
# RUN: echo "SECTIONS { .aaa : { KEEP (*(SORT(.aaa.*))) } }" > %t3.script
# RUN: ld.lld -o %t3 --script %t3.script %t2.o %t1.o
# RUN: llvm-objdump -s %t3 | FileCheck -check-prefix=SORTED_A %s

## Check that SORT_BY_NAME works (SORT is alias).
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_NAME(.aaa.*)) } }" > %t4.script
# RUN: ld.lld -o %t4 --script %t4.script %t2.o %t1.o
# RUN: llvm-objdump -s %t4 | FileCheck -check-prefix=SORTED_A %s

## Check that sections ordered by alignment.
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_ALIGNMENT(.aaa.*)) } }" > %t5.script
# RUN: ld.lld -o %t5 --script %t5.script %t1.o %t2.o
# RUN: llvm-objdump -s %t5 | FileCheck -check-prefix=SORTED_ALIGNMENT %s
# SORTED_ALIGNMENT:      Contents of section .aaa:
# SORTED_ALIGNMENT-NEXT:  05000000 00000000 00000000 00000000
# SORTED_ALIGNMENT-NEXT:  00000000 00000000 00000000 00000000
# SORTED_ALIGNMENT-NEXT:  11000000 00000000 00000000 00000000
# SORTED_ALIGNMENT-NEXT:  04000000 00000000 00000000 00000000
# SORTED_ALIGNMENT-NEXT:  22000000 00000000 03000000 00000000
# SORTED_ALIGNMENT-NEXT:  33000000 00000000 02000000 00000000
# SORTED_ALIGNMENT-NEXT:  44000000 00000000 01000000 00000000
# SORTED_ALIGNMENT-NEXT:  55000000 00000000

## SORT_NONE itself does not sort anything.
# RUN: echo "SECTIONS { .aaa : { *(SORT_NONE(.aaa.*)) } }" > %t6.script
# RUN: ld.lld -o %t7 --script %t6.script %t2.o %t1.o
# RUN: llvm-objdump -s %t7 | FileCheck -check-prefix=UNSORTED %s

## Check --sort-section alignment option.
# RUN: echo "SECTIONS { .aaa : { *(.aaa.*) } }" > %t7.script
# RUN: ld.lld --sort-section alignment -o %t8 --script %t7.script %t1.o %t2.o
# RUN: llvm-objdump -s %t8 | FileCheck -check-prefix=SORTED_ALIGNMENT %s

## Check --sort-section= form.
# RUN: ld.lld --sort-section=alignment -o %t8_1 --script %t7.script %t1.o %t2.o
# RUN: llvm-objdump -s %t8_1 | FileCheck -check-prefix=SORTED_ALIGNMENT %s

## Check --sort-section name option.
# RUN: echo "SECTIONS { .aaa : { *(.aaa.*) } }" > %t8.script
# RUN: ld.lld --sort-section name -o %t9 --script %t8.script %t1.o %t2.o
# RUN: llvm-objdump -s %t9 | FileCheck -check-prefix=SORTED_B %s

## SORT_NONE disables the --sort-section.
# RUN: echo "SECTIONS { .aaa : { *(SORT_NONE(.aaa.*)) } }" > %t9.script
# RUN: ld.lld --sort-section name -o %t10 --script %t9.script %t2.o %t1.o
# RUN: llvm-objdump -s %t10 | FileCheck -check-prefix=UNSORTED %s

## SORT_NONE as a inner sort directive.
# RUN: echo "SECTIONS { .aaa : { *(SORT_BY_NAME(SORT_NONE(.aaa.*))) } }" > %t10.script
# RUN: ld.lld -o %t11 --script %t10.script %t2.o %t1.o
# RUN: llvm-objdump -s %t11 | FileCheck -check-prefix=SORTED_A %s

.global _start
_start:
 nop

.section .aaa.5, "a"
.align 32
.quad 5

.section .aaa.1, "a"
.align 2
.quad 1

.section .aaa.3, "a"
.align 8
.quad 3

.section .aaa.2, "a"
.align 4
.quad 2

.section .aaa.4, "a"
.align 16
.quad 4
