# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY {                                  \
# RUN:   ROM (rwx): ORIGIN = 0x1000, LENGTH = 0x100    \
# RUN:   RAM (rwx): ORIGIN = 0x2000, LENGTH = 0x100    \
# RUN: }                                               \
# RUN: INCLUDE \"%t.script.inc\"                       \
# RUN: SECTIONS {                                      \
# RUN:  .text : { *(.text*) } > ALIAS_TEXT             \
# RUN:  .data : { *(.data*) } > ALIAS_DATA             \
# RUN: }" > %t.script

## .text to ROM, .data to RAM.
# RUN: echo "REGION_ALIAS (\"ALIAS_TEXT\", ROM);" > %t.script.inc
# RUN: echo "REGION_ALIAS (\"ALIAS_DATA\", RAM);" >> %t.script.inc
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s
# CHECK: .text       00000001 0000000000001000 TEXT DATA
# CHECK: .data       00000008 0000000000002000 DATA

## All to ROM.
# RUN: echo "REGION_ALIAS (\"ALIAS_TEXT\", ROM);" > %t.script.inc
# RUN: echo "REGION_ALIAS (\"ALIAS_DATA\", ROM);" >> %t.script.inc
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s --check-prefix=RAM
# RAM: .text         00000001 0000000000001000 TEXT DATA
# RAM: .data         00000008 0000000000001001 DATA

## Redefinition of region.
# RUN: echo "REGION_ALIAS (\"ROM\", ROM);" > %t.script.inc
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR1
# ERR1: {{.*}}script.inc:1: redefinition of memory region 'ROM'

## Redefinition of alias.
# RUN: echo "REGION_ALIAS (\"ALIAS_TEXT\", ROM);" > %t.script.inc
# RUN: echo "REGION_ALIAS (\"ALIAS_TEXT\", ROM);" >> %t.script.inc
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR2
# ERR2: {{.*}}script.inc:2: redefinition of memory region 'ALIAS_TEXT'

## Attemp to create an alias for undefined region.
# RUN: echo "REGION_ALIAS (\"ALIAS_TEXT\", FOO);" > %t.script.inc
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR3
# ERR3: {{.*}}script.inc:1: memory region 'FOO' is not defined

.text
.global _start
_start:
 nop

.section .data,"aw"
.quad 0
