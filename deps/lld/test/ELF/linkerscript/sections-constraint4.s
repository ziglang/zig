# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  .foo : ONLY_IF_RO { *(.foo) } \
# RUN:  .bar : {bar1 = .; *(.bar) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t
# RUN: llvm-readobj -t %t1 | FileCheck %s

# CHECK: Name: bar1

.global _start
_start:
  nop

.section .bar, "aw"
bar:
 .long 1

.section .foo, "aw"
 .long 0
