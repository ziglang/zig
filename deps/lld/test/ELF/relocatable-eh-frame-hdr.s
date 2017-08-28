# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --eh-frame-hdr -r %t.o -o %t
# RUN: llvm-readobj -s %t | FileCheck %s

# CHECK:       Sections [
# CHECK-NOT:    Name: .eh_frame_hdr

.section .foo,"ax",@progbits
.cfi_startproc
.cfi_endproc
