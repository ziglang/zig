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
#if defined(_SOFT_FLOAT) || defined(__NO_FPRS__)
	mflr 0
	bl 1f
	.hidden __hwcap
	.long __hwcap-.
1:	mflr 4
	lwz 5, 0(4)
	lwzx 4, 4, 5
	andis. 4, 4, 0x80
	beq 1f
	.long 0x11c35b21 /* evstdd 14,88(3) */
	.long 0x11e36321 /* ... */
	.long 0x12036b21
	.long 0x12237321
	.long 0x12437b21
	.long 0x12638321
	.long 0x12838b21
	.long 0x12a39321
	.long 0x12c39b21
	.long 0x12e3a321
	.long 0x1303ab21
	.long 0x1323b321
	.long 0x1343bb21
	.long 0x1363c321
	.long 0x1383cb21
	.long 0x13a3d321
	.long 0x13c3db21
	.long 0x13e3e321 /* evstdd 31,224(3) */
	.long 0x11a3eb21 /* evstdd 13,232(3) */
1:	mtlr 0
#else
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
