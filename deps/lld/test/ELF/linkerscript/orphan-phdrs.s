# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { \
# RUN:   exec PT_LOAD FLAGS(0x4 | 0x1); \
# RUN:   rw   PT_LOAD FLAGS(0x4 | 0x2); \
# RUN: } \
# RUN: SECTIONS { \
# RUN:  .text : { *(.text) } :exec \
# RUN:  .empty : { *(.empty) } :rw \
# RUN:  .rw : { *(.rw) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj -elf-output-style=GNU -s -l %t | FileCheck %s

## Check that the orphan section is placed correctly and belongs to
## the correct segment.

# CHECK: Section Headers
# CHECK: .text
# CHECK-NEXT: .orphan
# CHECK-NEXT: .rw

# CHECK: Segment Sections
# CHECK-NEXT: .text .orphan
# CHECK-NEXT: .rw

.section .text, "ax"
 ret

.section .rw, "aw"
 .quad 0

.section .orphan, "ax"
 ret
