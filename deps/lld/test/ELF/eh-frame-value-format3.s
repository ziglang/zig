# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld --eh-frame-hdr %t -o /dev/null

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

  .byte 0x0A # DW_EH_PE_sdata2
  .byte 0xFF
  .byte 0xFF
  .byte 0xFF
