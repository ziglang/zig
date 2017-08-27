# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:          .eh_frame : { *(.eh_frame) } \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -s -section=".eh_frame" %t1 | FileCheck %s

# CHECK: 0000 14000000 00000000 017a5200 01781001
# CHECK-NEXT: 0010 1b0c0708 90010000

.global _start
_start:
 nop

.section .dah,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc
