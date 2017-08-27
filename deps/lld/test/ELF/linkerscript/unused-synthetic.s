# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:    .got  : { *(.got) } \
# RUN:    .plt  : { *(.plt) } \
# RUN:    .text : { *(.text) } \
# RUN:  }" > %t.script
# RUN: ld.lld -shared -o %t.so --script %t.script %t.o

# RUN: llvm-objdump -section-headers %t.so | FileCheck %s
# CHECK-NOT:  .got
# CHECK-NOT:  .plt
# CHECK:      .text
# CHECK-NEXT: .dynsym

.global _start
_start:
  nop
