# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS {                  \
# RUN:  . = 0xffffffff80000200;          \
# RUN:  .text : AT (0x4200) { *(.text) } \
# RUN: }" > %t.script
# RUN: ld.lld %t.o --script %t.script -o %t
# RUN: llvm-readelf -program-headers %t | FileCheck %s

# Test that we put the header in the first PT_LOAD. We used to create a PT_LOAD
# just for it and it would have a different virtual to physical address delta.

# CHECK: Program Headers:
# CHECK:      Type  Offset   VirtAddr           PhysAddr
# CHECK-NEXT: PHDR  0x000040 0xffffffff80000040 0x0000000000004040
# CHECK-NEXT: LOAD  0x000000 0xffffffff80000000 0x0000000000004000
# CHECK-NOT:  LOAD

.global _start
_start:
nop
