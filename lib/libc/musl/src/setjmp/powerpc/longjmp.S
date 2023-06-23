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
#if defined(_SOFT_FLOAT) || defined(__NO_FPRS__)
	mflr 0
	bl 1f
	.hidden __hwcap
	.long __hwcap-.
1:	mflr 6
	lwz 5, 0(6)
	lwzx 6, 6, 5
	andis. 6, 6, 0x80
	beq 1f
	.long 0x11c35b01 /* evldd 14,88(3) */
	.long 0x11e36301 /* ... */
	.long 0x12036b01
	.long 0x12237301
	.long 0x12437b01
	.long 0x12638301
	.long 0x12838b01
	.long 0x12a39301
	.long 0x12c39b01
	.long 0x12e3a301
	.long 0x1303ab01
	.long 0x1323b301
	.long 0x1343bb01
	.long 0x1363c301
	.long 0x1383cb01
	.long 0x13a3d301
	.long 0x13c3db01
	.long 0x13e3e301 /* evldd 31,224(3) */
	.long 0x11a3eb01 /* evldd 13,232(3) */
1:	mtlr 0
#else
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

