.section .rodata.str,"aMS",@progbits,1
.asciz "bar"
.asciz "baz"
foo:
.asciz "foo"

.section .text.f2,"ax"
.globl f2
f2:
lea foo+42(%rip), %rax
