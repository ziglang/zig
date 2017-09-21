# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:         . = SIZEOF_HEADERS; \
# RUN:         .text : { *(.text) } \
# RUN:         . = ALIGN(0x1000); \
# RUN:         .data.rel.ro : { *(.data.rel.ro) } \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t -T %t.script %t.o -shared
# RUN: llvm-readobj -l %t | FileCheck %s


# Test that the orphan section foo is placed before the ALIGN and so the second
# PT_LOAD is aligned.


# CHECK:      Type: PT_LOAD
# CHECK-NEXT: Offset: 0x0

# CHECK:      Type: PT_LOAD
# CHECK-NEXT: Offset: 0x1000

nop
.section .data.rel.ro, "aw"
.byte 0

.section foo, "ax"
nop
