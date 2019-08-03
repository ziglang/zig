# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .eh_frame_hdr : { *(.eh_frame_hdr) *(.eh_frame) } }" > %t.script
# RUN: ld.lld -o %t --no-threads --eh-frame-hdr --script %t.script %t.o
# RUN: llvm-readobj -S -u %t | FileCheck %s

# CHECK: Name: .dah
# CHECK-NOT: Section
# CHECK: Address: 0x4D

# CHECK: initial_location: 0x4d

.global _start
_start:
 nop

.section .dah,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc
