#if !defined(_SOFT_FLOAT) && !defined(__NO_FPRS__)
.global feclearexcept
.type feclearexcept,@function
feclearexcept:
	andis. 3,3,0x3e00
	/* if (r3 & FE_INVALID) r3 |= all_invalid_flags */
	andis. 0,3,0x2000
	stwu 1,-16(1)
	beq- 0,1f
	oris 3,3,0x01f8
	ori  3,3,0x0700
1:
	/*
	 * note: fpscr contains various fpu status and control
	 * flags and we dont check if r3 may alter other flags
	 * than the exception related ones
	 * ufpscr &= ~r3
	 */
	mffs 0
	stfd 0,8(1)
	lwz 9,12(1)
	andc 9,9,3
	stw 9,12(1)
	lfd 0,8(1)
	mtfsf 255,0

	/* return 0 */
	li 3,0
	addi 1,1,16
	blr

.global feraiseexcept
.type feraiseexcept,@function
feraiseexcept:
	andis. 3,3,0x3e00
	/* if (r3 & FE_INVALID) r3 |= software_invalid_flag */
	andis. 0,3,0x2000
	stwu 1,-16(1)
	beq- 0,1f
	ori 3,3,0x0400
1:
	/* fpscr |= r3 */
	mffs 0
	stfd 0,8(1)
	lwz 9,12(1)
	or 9,9,3
	stw 9,12(1)
	lfd 0,8(1)
	mtfsf 255,0

	/* return 0 */
	li 3,0
	addi 1,1,16
	blr

.global fetestexcept
.type fetestexcept,@function
fetestexcept:
	andis. 3,3,0x3e00
	/* return r3 & fpscr */
	stwu 1,-16(1)
	mffs 0
	stfd 0,8(1)
	lwz 9,12(1)
	addi 1,1,16
	and 3,3,9
	blr

.global fegetround
.type fegetround,@function
fegetround:
	/* return fpscr & 3 */
	stwu 1,-16(1)
	mffs 0
	stfd 0,8(1)
	lwz 3,12(1)
	addi 1,1,16
	clrlwi 3,3,30
	blr

.global __fesetround
.hidden __fesetround
.type __fesetround,@function
__fesetround:
	/*
	 * note: invalid input is not checked, r3 < 4 must hold
	 * fpscr = (fpscr & -4U) | r3
	 */
	stwu 1,-16(1)
	mffs 0
	stfd 0,8(1)
	lwz 9,12(1)
	clrrwi 9,9,2
	or 9,9,3
	stw 9,12(1)
	lfd 0,8(1)
	mtfsf 255,0

	/* return 0 */
	li 3,0
	addi 1,1,16
	blr

.global fegetenv
.type fegetenv,@function
fegetenv:
	/* *r3 = fpscr */
	mffs 0
	stfd 0,0(3)
	/* return 0 */
	li 3,0
	blr

.global fesetenv
.type fesetenv,@function
fesetenv:
	cmpwi 3, -1
	bne 1f
	mflr 4
	bl 2f
	.zero 8
2:	mflr 3
	mtlr 4
1:	/* fpscr = *r3 */
	lfd 0,0(3)
	mtfsf 255,0
	/* return 0 */
	li 3,0
	blr
#endif
