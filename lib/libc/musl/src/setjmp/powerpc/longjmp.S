	.global _longjmp
	.global longjmp
	.type   _longjmp,@function
	.type   longjmp,@function
_longjmp:
longjmp:
	/*
	 * void longjmp(jmp_buf env, int val);
	 * put val into return register and restore the env saved in setjmp
	 * if val(r4) is 0, put 1 there.
	 */
	/* 0) move old return address into r0 */
	lwz 0, 0(3)
	/* 1) put it into link reg */
	mtlr 0
	/* 2 ) restore stack ptr */
	lwz 1, 4(3)
	/* 3) restore control reg */
	lwz 0, 8(3)
	mtcr 0
	/* 4) restore r14-r31 */
	lwz 14, 12(3)
	lwz 15, 16(3)
	lwz 16, 20(3)
	lwz 17, 24(3)
	lwz 18, 28(3)
	lwz 19, 32(3)
	lwz 20, 36(3)
	lwz 21, 40(3)
	lwz 22, 44(3)
	lwz 23, 48(3)
	lwz 24, 52(3)
	lwz 25, 56(3)
	lwz 26, 60(3)
	lwz 27, 64(3)
	lwz 28, 68(3)
	lwz 29, 72(3)
	lwz 30, 76(3)
	lwz 31, 80(3)
#ifndef _SOFT_FLOAT
	lfd 14,88(3)
	lfd 15,96(3)
	lfd 16,104(3)
	lfd 17,112(3)
	lfd 18,120(3)
	lfd 19,128(3)
	lfd 20,136(3)
	lfd 21,144(3)
	lfd 22,152(3)
	lfd 23,160(3)
	lfd 24,168(3)
	lfd 25,176(3)
	lfd 26,184(3)
	lfd 27,192(3)
	lfd 28,200(3)
	lfd 29,208(3)
	lfd 30,216(3)
	lfd 31,224(3)
#endif
	/* 5) put val into return reg r3 */
	mr 3, 4

	/* 6) check if return value is 0, make it 1 in that case */
	cmpwi cr7, 4, 0
	bne cr7, 1f
	li 3, 1
1:
	blr

