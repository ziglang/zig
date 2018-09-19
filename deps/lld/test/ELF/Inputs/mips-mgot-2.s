  .text
  .global foo2
foo2:
  lw     $2, %got(.data)($gp)     # page entry
  addi   $2, $2, %lo(.data)
  lw     $2, %call16(foo0)($gp)   # global entry
  lw     $2, %call16(foo2)($gp)   # global entry
  addiu  $2, $2, %tlsgd(tls0)     # tls gd entry
  addiu  $2, $2, %gottprel(tls0)  # tls got entry

  .data
  .space 0x20000

  .section .tdata,"awT",%progbits
  .global tls2
tls2:
  .word 0
