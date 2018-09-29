# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY { ram (rwx) : ORIGIN = 0, LENGTH = 2K } \
# RUN: SECTIONS { .text : { *(.text*) } > ram }" > %t.script
# RUN: ld.lld -o /dev/null --script %t.script %t

.text
.global _start
_start:
  .zero 1024

.section .text.foo,"ax",%progbits
foo:
  nop
