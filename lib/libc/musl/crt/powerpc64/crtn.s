.section .init
.align 2
	addi 1, 1, 32
	ld   0, 16(1)
	mtlr 0
	blr

.section .fini
.align 2
	addi 1, 1, 32
	ld   0, 16(1)
	mtlr 0
	blr
