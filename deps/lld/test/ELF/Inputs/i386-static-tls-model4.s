.section ".tdata", "awT", @progbits
.globl var
var:

.section .foo, "aw"
.global _start
_start:
 movl %gs:0, %eax
 leal var@ntpoff(%eax), %eax # R_386_TLS_LE
