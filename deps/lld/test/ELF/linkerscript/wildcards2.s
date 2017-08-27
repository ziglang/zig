# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
## Check that aabc is not included in text.
# RUN: echo "SECTIONS { \
# RUN:      .text : { *(.abc) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -section-headers %t.out | \
# RUN:   FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT:  Idx Name          Size
# CHECK-NEXT:    0               00000000
# CHECK-NEXT:    1 .text         00000004
# CHECK-NEXT:    2 aabc          00000004

.text
.section .abc,"ax",@progbits
.long 0

.text
.section aabc,"ax",@progbits
.long 0

.globl _start
_start:
