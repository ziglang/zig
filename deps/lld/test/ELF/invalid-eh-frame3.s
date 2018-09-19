# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: not ld.lld --eh-frame-hdr %t -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: corrupted .eh_frame: corrupted CIE (failed to read LEB128)
# CHECK-NEXT: >>> defined in {{.*}}:(.eh_frame+0xC)

.section .eh_frame
  .byte 0x08
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x01
  .byte 0x01
  .byte 0x00
  .byte 0x01
