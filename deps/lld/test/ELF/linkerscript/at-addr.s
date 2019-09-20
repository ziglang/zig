# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { . = 0x1000; \
# RUN:  .aaa : AT(ADDR(.aaa) - 0x500) { *(.aaa) } \
# RUN:  .bbb : AT(ADDR(.bbb) - 0x500) { *(.bbb) } \
# RUN:  .ccc : AT(ADDR(.ccc) - 0x500) { *(.ccc) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -l %t2 | FileCheck %s

# CHECK:      Type: PT_LOAD
# CHECK-NEXT:   Offset: 0x1000
# CHECK-NEXT:   VirtualAddress: 0x1000
# CHECK-NEXT:   PhysicalAddress: 0xB00
# CHECK:      Type: PT_LOAD
# CHECK-NEXT:   Offset: 0x1008
# CHECK-NEXT:   VirtualAddress: 0x1008
# CHECK-NEXT:   PhysicalAddress: 0xB08
# CHECK:      Type: PT_LOAD
# CHECK-NEXT:   Offset: 0x1010
# CHECK-NEXT:   VirtualAddress: 0x1010
# CHECK-NEXT:   PhysicalAddress: 0xB10

.global _start
_start:
 nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0
