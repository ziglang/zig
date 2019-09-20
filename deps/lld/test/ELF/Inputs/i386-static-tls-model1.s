.section ".tdata", "awT", @progbits
.globl var
var:

.section .foo, "aw"
.global _start
_start:
 movl $var@tpoff, %edx # R_386_TLS_LE_32
 movl %gs:0, %ecx
