.text
.globl _start
_start:
  .cfi_startproc
  .cfi_lsda 0, _ex
  nop
  .cfi_endproc

.data
_ex:
  .word 0
