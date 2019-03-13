.syntax unified

.section .init
.global _init
.type _init,%function
_init:
	push {r0,lr}

.section .fini
.global _fini
.type _fini,%function
_fini:
	push {r0,lr}
