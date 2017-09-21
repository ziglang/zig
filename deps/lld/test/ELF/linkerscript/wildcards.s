# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Default case: abc and abx included in text.
# RUN: echo "SECTIONS { \
# RUN:      .text : { *(.abc .abx) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=SEC-DEFAULT %s
# SEC-DEFAULT:      Sections:
# SEC-DEFAULT-NEXT: Idx Name          Size
# SEC-DEFAULT-NEXT:   0               00000000
# SEC-DEFAULT-NEXT:   1 .text         00000008
# SEC-DEFAULT-NEXT:   2 .abcd         00000004
# SEC-DEFAULT-NEXT:   3 .ad           00000004
# SEC-DEFAULT-NEXT:   4 .ag           00000004
# SEC-DEFAULT-NEXT:   5 .comment      00000008 {{[0-9a-f]*}}
# SEC-DEFAULT-NEXT:   6 .symtab       00000030
# SEC-DEFAULT-NEXT:   7 .shstrtab     00000038
# SEC-DEFAULT-NEXT:   8 .strtab       00000008

## Now replace the symbol with '?' and check that results are the same.
# RUN: echo "SECTIONS { \
# RUN:      .text : { *(.abc .ab?) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=SEC-DEFAULT %s

## Now see how replacing '?' with '*' will consume whole abcd.
# RUN: echo "SECTIONS { \
# RUN:      .text : { *(.abc .ab*) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=SEC-ALL %s
# SEC-ALL:      Sections:
# SEC-ALL-NEXT: Idx Name          Size
# SEC-ALL-NEXT:   0               00000000
# SEC-ALL-NEXT:   1 .text         0000000c
# SEC-ALL-NEXT:   2 .ad           00000004
# SEC-ALL-NEXT:   3 .ag           00000004
# SEC-ALL-NEXT:   4 .comment      00000008
# SEC-ALL-NEXT:   5 .symtab       00000030
# SEC-ALL-NEXT:   6 .shstrtab     00000032
# SEC-ALL-NEXT:   7 .strtab       00000008

## All sections started with .a are merged.
# RUN: echo "SECTIONS { \
# RUN:      .text : { *(.a*) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck -check-prefix=SEC-NO %s
# SEC-NO: Sections:
# SEC-NO-NEXT: Idx Name          Size
# SEC-NO-NEXT:   0               00000000
# SEC-NO-NEXT:   1 .text         00000014
# SEC-NO-NEXT:   2 .comment      00000008
# SEC-NO-NEXT:   3 .symtab       00000030
# SEC-NO-NEXT:   4 .shstrtab     0000002a
# SEC-NO-NEXT:   5 .strtab       00000008

.text
.section .abc,"ax",@progbits
.long 0

.text
.section .abx,"ax",@progbits
.long 0

.text
.section .abcd,"ax",@progbits
.long 0

.text
.section .ad,"ax",@progbits
.long 0

.text
.section .ag,"ax",@progbits
.long 0


.globl _start
_start:
