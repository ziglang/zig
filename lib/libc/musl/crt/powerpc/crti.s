.section .init
.align 2
.global _init
_init:
	stwu 1,-32(1)
	mflr 0
	stw 0,36(1)

.section .fini
.align 2
.global _fini
_fini:
	stwu 1,-32(1)
	mflr 0
	stw 0,36(1)
