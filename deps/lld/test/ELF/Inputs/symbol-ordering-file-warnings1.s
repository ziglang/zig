# This is a "bad" (absolute) instance of the symbol
multi = 1234

.text
.global shared
.type shared, @function
shared:
  movq  %rax, multi
  ret

.section .text.comdat,"axG",@progbits,comdat,comdat
.weak comdat
comdat:
  ret

.section .text.glob_or_wk,"ax",@progbits
.global glob_or_wk
glob_or_wk:
  ret
