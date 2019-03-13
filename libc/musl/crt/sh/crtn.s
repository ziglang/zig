.section .init
	lds.l @r15+, pr
	mov.l @r15+, r14
	mov.l @r15+, r12
	rts
	 add #4, r15

.section .fini
	lds.l @r15+, pr
	mov.l @r15+, r14
	mov.l @r15+, r12
	rts
	 add #4, r15
