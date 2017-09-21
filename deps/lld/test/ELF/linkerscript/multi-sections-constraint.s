# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  .text : { *(.text) } \
# RUN:  . = 0x1000; .aaa : ONLY_IF_RO { *(.aaa.*) } \
# RUN:  . = 0x2000; .aaa : ONLY_IF_RW { *(.aaa.*) } } " > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address          Type
# CHECK: .aaa          00000010 0000000000002000 DATA


# RUN: echo "SECTIONS { \
# RUN:  .text : { *(.text) } \
# RUN:  . = 0x1000; .aaa : ONLY_IF_RW { *(.aaa.*) } \
# RUN:  . = 0x2000; .aaa : ONLY_IF_RO { *(.aaa.*) } } " > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s --check-prefix=REV

# REV:      Sections:
# REV-NEXT: Idx Name          Size      Address          Type
# REV:  .aaa          00000010 0000000000001000 DATA

.global _start
_start:
 nop

.section .aaa.1, "aw"
.quad 1

.section .aaa.2, "aw"
.quad 1
