.section .init
.align 2
	lwz 0,36(1)
	addi 1,1,32
	mtlr 0
	blr

.section .fini
.align 2
	lwz 0,36(1)
	addi 1,1,32
	mtlr 0
	blr
