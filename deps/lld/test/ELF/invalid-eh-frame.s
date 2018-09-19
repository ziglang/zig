# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: not ld.lld --eh-frame-hdr %t -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: corrupted .eh_frame: unexpected end of CIE
# CHECK-NEXT: >>> defined in {{.*}}:(.eh_frame+0x8)

.section .eh_frame
  .byte 0x04
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
