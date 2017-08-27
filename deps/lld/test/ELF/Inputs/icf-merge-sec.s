.section .rodata.str,"aMS",@progbits,1
.asciz "bar"
.asciz "baz"
.asciz "foo"

.section .text.f2,"ax"
.globl f2
f2:
.quad .rodata.str+8
