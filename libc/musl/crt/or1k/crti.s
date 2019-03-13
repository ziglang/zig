.section .init
.global _init
_init:
	l.addi	r1,r1,-4
	l.sw	0(r1),r9

.section .fini
.global _fini
_fini:
	l.addi  r1,r1,-4
	l.sw    0(r1),r9
