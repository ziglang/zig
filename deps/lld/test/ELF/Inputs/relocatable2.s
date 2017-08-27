.text
.type xxx,@object
.bss
.globl xxx
.align 4
xxx:
.long 0
.size xxx, 4
.type yyy,@object
.globl yyy
.align 4
yyy:
.long 0
.size yyy, 4

.text
.globl bar
.align 16, 0x90
.type bar,@function
bar:
movl $8, xxx
movl $9, yyy
