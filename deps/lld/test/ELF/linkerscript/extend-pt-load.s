# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# This test demonstrates an odd consequence of the way we handle sections with just symbol
# assignments.

# First, run a test with no such section.

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:	.dynsym : {  } \
# RUN:	.hash : {  } \
# RUN:	.dynstr : {  } \
# RUN:  .text : { *(.text) } \
# RUN:  . = ALIGN(0x1000); \
# RUN:  .data.rel.ro : { *(.data.rel.ro) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t.o -shared
# RUN: llvm-readobj --elf-output-style=GNU -l -s %t1 | FileCheck --check-prefix=CHECK1 %s

# CHECK1:      .text        PROGBITS 00000000000001bc 0001bc 000001 00 AX
# CHECK1-NEXT: .data.rel.ro PROGBITS 0000000000001000 001000 000001 00 WA

# CHECK1:      LOAD 0x000000 0x0000000000000000 0x0000000000000000 0x0001bd 0x0001bd R E
# CHECK1-NEXT: LOAD 0x001000 0x0000000000001000 0x0000000000001000 0x000068 0x000068 RW

# Then add the section bar. Note how bar is given AX flags, which causes the PT_LOAD to now
# cover the padding bits created by ALIGN.

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:	.dynsym : {  } \
# RUN:	.hash : {  } \
# RUN:	.dynstr : {  } \
# RUN:  .text : { *(.text) } \
# RUN:  . = ALIGN(0x1000); \
# RUN:  bar : { HIDDEN(bar_sym = .); } \
# RUN:  .data.rel.ro : { *(.data.rel.ro) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t2 --script %t.script %t.o -shared
# RUN: llvm-readobj --elf-output-style=GNU -l -s %t2 | FileCheck --check-prefix=CHECK2 %s

# CHECK2:      .text        PROGBITS 00000000000001bc 0001bc 000001 00 AX
# CHECK2-NEXT: bar          PROGBITS 0000000000001000 001000 000000 00 AX
# CHECK2-NEXT: .data.rel.ro PROGBITS 0000000000001000 001000 000001 00 WA

# CHECK2:      LOAD 0x000000 0x0000000000000000 0x0000000000000000 0x001000 0x001000 R E
# CHECK2-NEXT: LOAD 0x001000 0x0000000000001000 0x0000000000001000 0x000068 0x000068 RW

# If the current behavior becomes a problem we should consider just moving the commands out
# of the section. That is, handle the above like the following test.

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:	.dynsym : {  } \
# RUN:	.hash : {  } \
# RUN:	.dynstr : {  } \
# RUN:  .text : { *(.text) } \
# RUN:  . = ALIGN(0x1000); \
# RUN:  HIDDEN(bar_sym = .); \
# RUN:  .data.rel.ro : { *(.data.rel.ro) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t3 --script %t.script %t.o -shared
# RUN: llvm-readobj --elf-output-style=GNU -l -s %t3 | FileCheck --check-prefix=CHECK1 %s

nop

.section .data.rel.ro, "aw"
.byte 0
