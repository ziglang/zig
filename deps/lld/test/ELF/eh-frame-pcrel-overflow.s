# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/eh-frame-pcrel-overflow.s -o %t1.o
# RUN: ld.lld --eh-frame-hdr -Ttext=0x90000000 %t.o -o /dev/null
# RUN: not ld.lld --eh-frame-hdr %t.o %t1.o -o /dev/null 2>&1 | FileCheck %s
# CHECK: error: {{.*}}.o:(.eh_frame): PC offset is too large: 0x90000eac

.text
.global _start
_start:
  ret

.section .eh_frame, "a"
  .long 12   # Size
  .long 0x00 # ID
  .byte 0x01 # Version.

  .byte 0x52 # Augmentation string: 'R','\0'
  .byte 0x00

  .byte 0x01

  .byte 0x01 # LEB128
  .byte 0x01 # LEB128

  .byte 0x00 # DW_EH_PE_absptr

  .byte 0xFF

  .long 12  # Size
  .long 0x14 # ID
  .quad _start + 0x70000000
