# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { \
# RUN:   exec PT_LOAD FLAGS(0x4 | 0x1); \
# RUN:   ro   PT_LOAD FLAGS(0x4); \
# RUN: } \
# RUN: SECTIONS { \
# RUN:  .pad : { QUAD(0); } :exec \
# RUN:  .text : { *(.text) } \
# RUN:  .ro : { *(.ro) } :ro \
# RUN: }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S -l %t | FileCheck %s

## The ".pad" section is not "live" and should be ignored by the
## orphan placement.
##
## Check that the orphan section is placed correctly and belongs to
## the correct segment.

# CHECK: Section Headers
# CHECK: .pad
# CHECK-NEXT: .text
# CHECK-NEXT: .orphan2
# CHECK-NEXT: .ro
# CHECK-NEXT: .orphan1

# CHECK: Segment Sections
# CHECK-NEXT: .pad .text .orphan2
# CHECK-NEXT: .ro .orphan1

.section .text,"ax"
 ret

.section .ro,"a"
 .byte 0

.section .orphan1,"a"
 .byte 0

.section .orphan2,"ax"
 ret
