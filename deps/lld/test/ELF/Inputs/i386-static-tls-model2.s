.section ".tdata", "awT", @progbits
.globl var
var:

.section .foo, "aw"
.global _start
_start: 
 movl %gs:0, %eax
 addl var@gotntpoff(%ebx), %eax # R_386_TLS_GOTIE
