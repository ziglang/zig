 .syntax unified
 .text
 .globl __tls_get_addr
 .type __tls_get_addr,%function
__tls_get_addr:
 bx lr

.section       .tbss,"awT",%nobits
 .p2align  2
y:
 .space 4
 .globl y
 .type  y, %object
