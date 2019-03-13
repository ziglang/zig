.section .init
	l.lwz	r9,0(r1)
	l.jr	r9
	 l.addi	r1,r1,4

.section .fini
	l.lwz	r9,0(r1)
	l.jr	r9
	 l.addi	r1,r1,4
