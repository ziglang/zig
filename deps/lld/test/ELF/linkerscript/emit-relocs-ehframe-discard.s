# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: echo "SECTIONS { /DISCARD/ : { *(.eh_frame) } }" > %t.script
# RUN: ld.lld --emit-relocs --script %t.script %t1.o -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

# CHECK-NOT: .rela.eh_frame

.section .foo,"ax",@progbits
.cfi_startproc
.cfi_endproc
