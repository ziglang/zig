.section .rodata.str,"aMS",@progbits,1
.asciz "bar"
.asciz "baz"
boo:
.asciz "boo"

.section .text.f2,"ax"
.globl f2
f2:
lea boo+42(%rip), %rax
