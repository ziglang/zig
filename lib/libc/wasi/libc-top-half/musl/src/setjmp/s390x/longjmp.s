	.global _longjmp
	.global longjmp
	.type   _longjmp,@function
	.type   longjmp,@function
_longjmp:
longjmp:

1:
	lmg %r6, %r15, 0(%r2)

	ld  %f8, 10*8(%r2)
	ld  %f9, 11*8(%r2)
	ld %f10, 12*8(%r2)
	ld %f11, 13*8(%r2)
	ld %f12, 14*8(%r2)
	ld %f13, 15*8(%r2)
	ld %f14, 16*8(%r2)
	ld %f15, 17*8(%r2)

	ltgr %r2, %r3
	bnzr %r14
	lhi  %r2, 1
	br   %r14
