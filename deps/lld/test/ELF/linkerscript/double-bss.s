# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { . = SIZEOF_HEADERS; " > %t.script
# RUN: echo ".text : { *(.text*) }" >> %t.script
# RUN: echo ".bss1 : { *(.bss) }" >> %t.script
# RUN: echo ".bss2 : { *(COMMON) }" >> %t.script
# RUN: echo "}" >> %t.script

# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK:      .bss1          00000004 0000000000000122 BSS
# CHECK-NEXT: .bss2          00000080 0000000000000128 BSS

.globl _start
_start:
  jmp _start

.bss
.zero 4

.comm q,128,8
