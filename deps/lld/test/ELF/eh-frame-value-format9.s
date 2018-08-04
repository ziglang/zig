# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld --eh-frame-hdr %t.o -o %t 2>&1 | FileCheck %s
# CHECK: error: unknown FDE size encoding

.section .eh_frame, "ax"
  .long 12   # Size
  .long 0x00 # ID
  .byte 0x01 # Version.
  
  .byte 0x52 # Augmentation string: 'R','\0'
  .byte 0x00
  
# Code and data alignment factors.
  .byte 0x01 # LEB128
  .byte 0x01 # LEB128

# Return address register.
  .byte 0x01 # LEB128

  .byte 0xFE # 'R' value: invalid <0xFE>

  .byte 0xFF

  .long 12  # Size
  .long 0x14 # ID
  .quad .eh_frame
