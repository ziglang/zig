.syntax unified

.section .init
.global _init
.type _init,%function
.align 2
_init:
	push {r0,lr}

.section .fini
.global _fini
.type _fini,%function
.align 2
_fini:
	push {r0,lr}
