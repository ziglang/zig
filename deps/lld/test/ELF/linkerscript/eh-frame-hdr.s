# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:          .eh_frame_hdr : {} \
# RUN:          .eh_frame : {} \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t1 --eh-frame-hdr --script %t.script %t
# RUN: llvm-objdump -s -section=".eh_frame_hdr" %t1 | FileCheck %s

# CHECK:      011b033b 14000000 01000000 49000000
# CHECK-NEXT: 30000000

.global _start
_start:
 nop

.section .dah,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc
