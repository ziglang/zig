	.global _longjmp
	.global longjmp
	.type   _longjmp,@function
	.type   longjmp,@function
_longjmp:
longjmp:
	# 0) move old return address into the link register
	ld   0,  0*8(3)
	mtlr 0
	# 1) restore cr
	ld   0,  1*8(3)
	mtcr 0
	# 2) restore SP
	ld   1,  2*8(3)
	# 3) restore TOC into both r2 and the caller's stack.
	#    Which location is required depends on whether setjmp was called
	#    locally or non-locally, but it's always safe to restore to both.
	ld   2,  3*8(3)
	std  2,   24(1)
	# 4) restore r14-r31
	ld  14,  4*8(3)
	ld  15,  5*8(3)
	ld  16,  6*8(3)
	ld  17,  7*8(3)
	ld  18,  8*8(3)
	ld  19,  9*8(3)
	ld  20, 10*8(3)
	ld  21, 11*8(3)
	ld  22, 12*8(3)
	ld  23, 13*8(3)
	ld  24, 14*8(3)
	ld  25, 15*8(3)
	ld  26, 16*8(3)
	ld  27, 17*8(3)
	ld  28, 18*8(3)
	ld  29, 19*8(3)
	ld  30, 20*8(3)
	ld  31, 21*8(3)
	# 5) restore floating point registers f14-f31
	lfd 14, 22*8(3)
	lfd 15, 23*8(3)
	lfd 16, 24*8(3)
	lfd 17, 25*8(3)
	lfd 18, 26*8(3)
	lfd 19, 27*8(3)
	lfd 20, 28*8(3)
	lfd 21, 29*8(3)
	lfd 22, 30*8(3)
	lfd 23, 31*8(3)
	lfd 24, 32*8(3)
	lfd 25, 33*8(3)
	lfd 26, 34*8(3)
	lfd 27, 35*8(3)
	lfd 28, 36*8(3)
	lfd 29, 37*8(3)
	lfd 30, 38*8(3)
	lfd 31, 39*8(3)

	# 6) restore vector registers v20-v31
	addi 3, 3, 40*8
	lvx 20, 0, 3 ; addi 3, 3, 16
	lvx 21, 0, 3 ; addi 3, 3, 16
	lvx 22, 0, 3 ; addi 3, 3, 16
	lvx 23, 0, 3 ; addi 3, 3, 16
	lvx 24, 0, 3 ; addi 3, 3, 16
	lvx 25, 0, 3 ; addi 3, 3, 16
	lvx 26, 0, 3 ; addi 3, 3, 16
	lvx 27, 0, 3 ; addi 3, 3, 16
	lvx 28, 0, 3 ; addi 3, 3, 16
	lvx 29, 0, 3 ; addi 3, 3, 16
	lvx 30, 0, 3 ; addi 3, 3, 16
	lvx 31, 0, 3

	# 7) return r4 ? r4 : 1
	mr    3,   4
	cmpwi cr7, 4, 0
	bne   cr7, 1f
	li    3,   1
1:
	blr

