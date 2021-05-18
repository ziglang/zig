.section .init
.global  _init
.type    _init, @function
_init:
	add #-4, r15
	mov.l r12, @-r15
	mov.l r14, @-r15
	sts.l pr, @-r15
	mov r15, r14
	nop

.section .fini
.global  _fini
.type    _fini, @function
_fini:
	add #-4, r15
	mov.l r12, @-r15
	mov.l r14, @-r15
	sts.l pr, @-r15
	mov r15, r14
	nop
