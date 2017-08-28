.section .text.foo,"axG",@progbits,foo,comdat,unique,0
foo:
  nop

.section .debug_info
.long .text.foo
