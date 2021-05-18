.section .init
	lwi r15, r1, 0
	rtsd r15, 8
	addi r1, r1, 32

.section .fini
	lwi r15, r1, 0
	rtsd r15, 8
	addi r1, r1, 32
