# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --eh-frame-hdr
# RUN: llvm-objdump -s %t2 | FileCheck %s

# CHECK: Contents of section .eh_frame_hdr:
# CHECK-NEXT: 200158 011b033b 1c000000 01000000 a80e0000
#                                      ^ FDE count
# CHECK-NEXT: 200168 38000000 00000000 00000000
#                    ^ FDE for f2

.globl _start, f1, f2
_start:
  ret

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
