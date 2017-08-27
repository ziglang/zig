# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { .text : { *(.text*) } }" > %t.script
# RUN: ld.lld %t --gc-sections --script %t.script -o %t1
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT:  Name      Size
# CHECK:       .text     00000001

.section .text.foo, "ax"
.global _start
_start:
  nop

.section .text.bar, "ax"
.global bar
bar:
  nop
