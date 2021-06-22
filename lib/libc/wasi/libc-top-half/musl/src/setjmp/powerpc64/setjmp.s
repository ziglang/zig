	.global __setjmp
	.global _setjmp
	.global setjmp
	.type   __setjmp,@function
	.type   _setjmp,@function
	.type   setjmp,@function
__setjmp:
_setjmp:
setjmp:
	ld 5, 24(1)   # load from the TOC slot in the caller's stack frame
	b __setjmp_toc

	.localentry __setjmp,.-__setjmp
	.localentry _setjmp,.-_setjmp
	.localentry setjmp,.-setjmp
	mr 5, 2

	.global __setjmp_toc
	.hidden __setjmp_toc
	# same as normal setjmp, except TOC pointer to save is provided in r5.
	# r4 would normally be the 2nd parameter, but we're using r5 to simplify calling from sigsetjmp.
	# solves the problem of knowing whether to save the TOC pointer from r2 or the caller's stack frame.
__setjmp_toc:
	# 0) store IP into 0, then into the jmpbuf pointed to by r3 (first arg)
	mflr  0
	std   0,  0*8(3)
	# 1) store cr
	mfcr  0
	std   0,  1*8(3)
	# 2) store SP and TOC
	std   1,  2*8(3)
	std   5,  3*8(3)
	# 3) store r14-31
	std  14,  4*8(3)
	std  15,  5*8(3)
	std  16,  6*8(3)
	std  17,  7*8(3)
	std  18,  8*8(3)
	std  19,  9*8(3)
	std  20, 10*8(3)
	std  21, 11*8(3)
	std  22, 12*8(3)
	std  23, 13*8(3)
	std  24, 14*8(3)
	std  25, 15*8(3)
	std  26, 16*8(3)
	std  27, 17*8(3)
	std  28, 18*8(3)
	std  29, 19*8(3)
	std  30, 20*8(3)
	std  31, 21*8(3)
	# 4) store floating point registers f14-f31
	stfd 14, 22*8(3)
	stfd 15, 23*8(3)
	stfd 16, 24*8(3)
	stfd 17, 25*8(3)
	stfd 18, 26*8(3)
	stfd 19, 27*8(3)
	stfd 20, 28*8(3)
	stfd 21, 29*8(3)
	stfd 22, 30*8(3)
	stfd 23, 31*8(3)
	stfd 24, 32*8(3)
	stfd 25, 33*8(3)
	stfd 26, 34*8(3)
	stfd 27, 35*8(3)
	stfd 28, 36*8(3)
	stfd 29, 37*8(3)
	stfd 30, 38*8(3)
	stfd 31, 39*8(3)

	# 5) store vector registers v20-v31
	addi  3, 3, 40*8
	stvx 20, 0, 3 ; addi 3, 3, 16
	stvx 21, 0, 3 ; addi 3, 3, 16
	stvx 22, 0, 3 ; addi 3, 3, 16
	stvx 23, 0, 3 ; addi 3, 3, 16
	stvx 24, 0, 3 ; addi 3, 3, 16
	stvx 25, 0, 3 ; addi 3, 3, 16
	stvx 26, 0, 3 ; addi 3, 3, 16
	stvx 27, 0, 3 ; addi 3, 3, 16
	stvx 28, 0, 3 ; addi 3, 3, 16
	stvx 29, 0, 3 ; addi 3, 3, 16
	stvx 30, 0, 3 ; addi 3, 3, 16
	stvx 31, 0, 3

	# 6) return 0
	li 3, 0
	blr
