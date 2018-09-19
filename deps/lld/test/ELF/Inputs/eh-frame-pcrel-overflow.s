.text
.global foo
foo:
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
  .quad foo + 0x90000000
