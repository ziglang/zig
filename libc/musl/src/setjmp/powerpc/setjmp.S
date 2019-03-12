	.global ___setjmp
	.hidden ___setjmp
	.global __setjmp
	.global _setjmp
	.global setjmp
	.type   __setjmp,@function
	.type   _setjmp,@function
	.type   setjmp,@function
___setjmp:
__setjmp:
_setjmp:
setjmp:
	/* 0) store IP int 0, then into the jmpbuf pointed to by r3 (first arg) */
	mflr 0
	stw 0, 0(3)
	/* 1) store reg1 (SP) */
	stw 1, 4(3)
	/* 2) store cr */
	mfcr 0
	stw 0, 8(3)
	/* 3) store r14-31 */
	stw 14, 12(3)
	stw 15, 16(3)
	stw 16, 20(3)
	stw 17, 24(3)
	stw 18, 28(3)
	stw 19, 32(3)
	stw 20, 36(3)
	stw 21, 40(3)
	stw 22, 44(3)
	stw 23, 48(3)
	stw 24, 52(3)
	stw 25, 56(3)
	stw 26, 60(3)
	stw 27, 64(3)
	stw 28, 68(3)
	stw 29, 72(3)
	stw 30, 76(3)
	stw 31, 80(3)
#ifndef _SOFT_FLOAT
	stfd 14,88(3)
	stfd 15,96(3)
	stfd 16,104(3)
	stfd 17,112(3)
	stfd 18,120(3)
	stfd 19,128(3)
	stfd 20,136(3)
	stfd 21,144(3)
	stfd 22,152(3)
	stfd 23,160(3)
	stfd 24,168(3)
	stfd 25,176(3)
	stfd 26,184(3)
	stfd 27,192(3)
	stfd 28,200(3)
	stfd 29,208(3)
	stfd 30,216(3)
	stfd 31,224(3)
#endif
	/* 4) set return value to 0 */
	li 3, 0
	/* 5) return */
	blr
