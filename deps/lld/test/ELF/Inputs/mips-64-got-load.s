  .text
  .global foo1
foo1:
  ld $2, %got_disp(local1)($gp)

  .bss
local1:
  .word 0
