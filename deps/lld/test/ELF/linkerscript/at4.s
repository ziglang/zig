# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  . = 0x1000; \
# RUN:  .aaa : { *(.aaa) } \
# RUN:  .bbb : AT(0x2008) { *(.bbb) } \
# RUN:  .ccc : { *(.ccc) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -l %t2 | FileCheck %s

# CHECK:        Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x1000
# CHECK-NEXT:     PhysicalAddress: 0x1000
# CHECK-NEXT:     FileSize: 8
# CHECK-NEXT:     MemSize: 8
# CHECK:        Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1008
# CHECK-NEXT:     VirtualAddress: 0x1008
# CHECK-NEXT:     PhysicalAddress: 0x2008
# CHECK-NEXT:     FileSize: 17
# CHECK-NEXT:     MemSize: 17

.global _start
_start:
 nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0
