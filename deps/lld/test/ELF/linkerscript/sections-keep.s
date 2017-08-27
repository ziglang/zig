# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/keep.s -o %t2.o

## First check that section "keep" is garbage collected without using KEEP
# RUN: echo "SECTIONS { \
# RUN:  .text : { *(.text) } \
# RUN:  .keep : { *(.keep) } \
# RUN:  .temp : { *(.temp) }}" > %t.script
# RUN: ld.lld --gc-sections -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | \
# RUN:   FileCheck -check-prefix=SECGC %s
# SECGC:      Sections:
# SECGC-NEXT: Idx Name          Size
# SECGC-NEXT:   0               00000000
# SECGC-NEXT:   1 .text         00000007
# SECGC-NEXT:   2 .temp         00000004

## Now apply KEEP command to preserve the section.
# RUN: echo "SECTIONS { \
# RUN:  .text : { *(.text) } \
# RUN:  .keep : { KEEP(*(.keep)) } \
# RUN:  .temp : { *(.temp) }}" > %t.script
# RUN: ld.lld --gc-sections -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | \
# RUN:   FileCheck -check-prefix=SECNOGC %s
# SECNOGC:      Sections:
# SECNOGC-NEXT: Idx Name          Size
# SECNOGC-NEXT:   0               00000000
# SECNOGC-NEXT:   1 .text         00000007
# SECNOGC-NEXT:   2 .keep         00000004
# SECNOGC-NEXT:   3 .temp         00000004

## A section name matches two entries in the SECTIONS directive. The
## first one doesn't have KEEP, the second one does. If section that have
## KEEP is the first in order then section is NOT collected.
# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  .keep : { KEEP(*(.keep)) } \
# RUN:  .nokeep : { *(.keep) }}" > %t.script
# RUN: ld.lld --gc-sections -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck -check-prefix=MIXED1 %s
# MIXED1:      Sections:
# MIXED1-NEXT: Idx Name          Size
# MIXED1-NEXT:   0               00000000
# MIXED1-NEXT:   1 .keep         00000004
# MIXED1-NEXT:   2 .text         00000007 00000000000000ec TEXT DATA
# MIXED1-NEXT:   3 .temp         00000004 00000000000000f3 DATA
# MIXED1-NEXT:   4 .comment      00000008 0000000000000000
# MIXED1-NEXT:   5 .symtab       00000060 0000000000000000
# MIXED1-NEXT:   6 .shstrtab     00000036 0000000000000000
# MIXED1-NEXT:   7 .strtab       00000012 0000000000000000

## The same, but now section without KEEP is at first place.
## gold and bfd linkers disagree here. gold collects .keep while
## bfd keeps it. Our current behavior is compatible with bfd although
## we can choose either way.
# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  .nokeep : { *(.keep) } \
# RUN:  .keep : { KEEP(*(.keep)) }}" > %t.script
# RUN: ld.lld --gc-sections -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck -check-prefix=MIXED2 %s
# MIXED2:      Sections:
# MIXED2-NEXT: Idx Name          Size
# MIXED2-NEXT:   0               00000000
# MIXED2-NEXT:   1 .nokeep       00000004 00000000000000e8 DATA
# MIXED2-NEXT:   2 .text         00000007 00000000000000ec TEXT DATA
# MIXED2-NEXT:   3 .temp         00000004 00000000000000f3 DATA
# MIXED2-NEXT:   4 .comment      00000008 0000000000000000
# MIXED2-NEXT:   5 .symtab       00000060 0000000000000000
# MIXED2-NEXT:   6 .shstrtab     00000038 0000000000000000
# MIXED2-NEXT:   7 .strtab       00000012 0000000000000000

# Check file pattern for kept sections.
# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  .keep : { KEEP(*2.o(.keep)) } \
# RUN:  }" > %t.script
# RUN: ld.lld --gc-sections -o %t1 --script %t.script %t2.o %t
# RUN: llvm-objdump -s %t1 | FileCheck -check-prefix=FILEMATCH %s
# FILEMATCH:        Contents of section .keep:
# FILEMATCH-NEXT:   00e8 41414141  AAAA

.global _start
_start:
 mov temp, %eax

.section .keep, "a"
keep:
 .long 1

.section .temp, "a"
temp:
 .long 2
