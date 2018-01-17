# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-linux %s -o %t.o
# RUN: echo "SECTIONS { .data 0x4000 : { *(.data) } .text 0x2000 : { *(.text) } }" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t.so --script %t.script %t.o -shared
# RUN: llvm-objdump -section-headers %t.so | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address          Type
# CHECK-NEXT:   0               00000000 0000000000000000
# CHECK-NEXT:   1 .data         00000008 0000000000004000  DATA
# CHECK-NEXT:   2 .dynamic      00000060 0000000000004008
# CHECK-NEXT:   3 .text         00000008 0000000000002000  TEXT DATA
# CHECK-NEXT:   4 .dynsym       00000018 0000000000002008
# CHECK-NEXT:   5 .hash         00000010 0000000000002020
# CHECK-NEXT:   6 .dynstr       00000001 0000000000002030

.quad 0
.data
.quad 0
