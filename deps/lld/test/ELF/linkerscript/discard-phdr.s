# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { \
# RUN:   exec PT_LOAD FLAGS(0x4 | 0x1); \
# RUN: } \
# RUN: SECTIONS { \
# RUN:  .text : { *(.text) } :exec \
# RUN:  .foo : { *(.foo) } \
# RUN:  .bar : { *(.bar) } \
# RUN:  /DISCARD/ : { *(.discard) } :NONE \
# RUN: }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S -l %t | FileCheck --implicit-check-not=/DISCARD/ %s

## Check that /DISCARD/ does not interfere with the assignment of segments to
## sections.

# CHECK: Section Headers
# CHECK: .text
# CHECK-NEXT: .foo
# CHECK-NEXT: .bar

# CHECK: Segment Sections
# CHECK-NEXT: .text .foo .bar

.section .text,"ax"
 ret

.section .foo,"a"
 .byte 0

.section .bar,"ax"
 ret

.section .discard
 .byte 0
