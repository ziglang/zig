# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

## Test that section .foo is not placed in any segment when assigned to segment
## NONE in the linker script and segment NONE is not defined.
# RUN: echo "PHDRS {text PT_LOAD;} \
# RUN:       SECTIONS { \
# RUN:           .text : {*(.text .text*)} :text \
# RUN:           .foo : {*(.foo)} :NONE \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S -l %t | FileCheck %s

## Test that section .foo is placed in segment NONE when assigned to segment
## NONE in the linker script and segment NONE is defined.
# RUN: echo "PHDRS {text PT_LOAD; NONE PT_LOAD;} \
# RUN:       SECTIONS { \
# RUN:           .text : {*(.text .text*)} :text \
# RUN:           .foo : {*(.foo)} :NONE \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S -l %t | FileCheck --check-prefix=DEFINED %s

# CHECK: Section to Segment mapping:
# CHECK-NEXT: Segment Sections...
# CHECK-NOT: .foo

# DEFINED: Section to Segment mapping:
# DEFINED-NEXT: Segment Sections...
# DEFINED-NEXT:  00     .text
# DEFINED-NEXT:  01     .foo

.global _start
_start:
 nop

.section .foo,"a"
foo:
 .long 0
