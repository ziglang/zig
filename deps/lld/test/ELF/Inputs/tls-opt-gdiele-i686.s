.type tlsshared0,@object
.section .tbss,"awT",@nobits
.globl tlsshared0
.align 4
tlsshared0:
 .long 0
 .size tlsshared0, 4

.type  tlsshared1,@object
.globl tlsshared1
.align 4
tlsshared1:
 .long 0
 .size tlsshared1, 4

.text
 .globl __tls_get_addr
 .align 16, 0x90
 .type __tls_get_addr,@function
__tls_get_addr:
