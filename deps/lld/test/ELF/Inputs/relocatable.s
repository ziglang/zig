.text
.type xx,@object
.bss
.globl xx
.align 4
xx:
.long 0
.size xx, 4
.type yy,@object
.globl yy
.align 4
yy:
.long 0
.size yy, 4

.text
.globl foo
.align 16, 0x90
.type foo,@function
foo:
movl $1, xx
movl $2, yy
