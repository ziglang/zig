.rodata
.globl a
.size a, 4
.type a, @object
a:
.word 1

.section .data.rel.ro,"aw",%progbits
.globl b
.size b, 4
.type b, @object
b:
.word 2
