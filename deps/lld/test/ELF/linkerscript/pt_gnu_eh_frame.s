# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { /DISCARD/ : { *(.eh_frame*) *(.eh_frame_hdr*) } }" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t

.global _start
_start:
 nop

.section .dah,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc
