  .text
  .global foo1
foo1:
  addiu  $2, $2, %gottprel(tls0)  # tls got entry
  addiu  $2, $2, %gottprel(tls1)  # tls got entry

  .section .tdata,"awT",%progbits
  .global tls1
tls1:
  .word 0
