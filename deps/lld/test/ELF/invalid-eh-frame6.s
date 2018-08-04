# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: not ld.lld --eh-frame-hdr %t -o /dev/null 2>&1 | FileCheck %s

# CHECK: error: corrupted .eh_frame: unknown FDE encoding
# CHECK-NEXT: >>> defined in {{.*}}:(.eh_frame+0xE)

.section .eh_frame
  .byte 0x0E
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x00
  .byte 0x01
  
  .byte 0x50 # Augmentation string: 'P','\0'
  .byte 0x00
  
  .byte 0x01
  
  .byte 0x01 # LEB128
  .byte 0x01 # LEB128

  .byte 0x01
  .byte 0x01
  .byte 0x01
  .byte 0x01
