# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --eh-frame-hdr
# RUN: llvm-objdump -s -section-headers %t2 | FileCheck %s

## Check .eh_frame_hdr contains single FDE and no garbage data at tail.
# CHECK: Sections:
# CHECK: Idx Name          Size
# CHECK:     .eh_frame_hdr 00000014

# CHECK: Contents of section .eh_frame_hdr:
# CHECK-NEXT: 200158 011b033b 14000000 01000000
#                                      ^ FDE count

.globl f1, f2

.section .text.f1, "ax"
f1:
  .cfi_startproc
  ret
  .cfi_endproc

.section .text.f2, "ax"
f2:
  .cfi_startproc
  ret
  .cfi_endproc
