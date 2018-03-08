# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:         .sec1 (NOLOAD) : { . += 1; } \
# RUN:         .text          : { *(.text) } \
# RUN:       };" > %t.script
# RUN: ld.lld %t.o -T %t.script -o %t
# RUN: llvm-readelf --sections %t | FileCheck %s

# We used to misalign section offsets if the first section in a
# PT_LOAD was SHT_NOBITS.

# CHECK: [ 2] .text  PROGBITS  0000000000000010 001010 000010 00  AX  0   0 16

.global _start
_start:
  nop
.p2align 4
