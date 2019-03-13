.section .init
.global _init
.align 2
_init:
	addi r1, r1, -32
	swi r15, r1, 0

.section .fini
.global _fini
.align 2
_fini:
	addi r1, r1, -32
	swi r15, r1, 0
