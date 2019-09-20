# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --section-start .data=0x20 \
# RUN: --section-start .bss=0x30 --section-start .text=0x10 -o %t1
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT:  Idx Name          Size     VMA              Type
# CHECK-NEXT:    0               00000000 0000000000000000
# CHECK-NEXT:    1 .text         00000001 0000000000000010 TEXT
# CHECK-NEXT:    2 .data         00000004 0000000000000020 DATA
# CHECK-NEXT:    3 .bss          00000004 0000000000000030 BSS

.text
.globl _start
_start:
 nop

.data
.long 0

.bss
.zero 4
