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
	stmg %r6, %r15, 0(%r2)

	std  %f8,  10*8(%r2)
	std  %f9,  11*8(%r2)
	std  %f10, 12*8(%r2)
	std  %f11, 13*8(%r2)
	std  %f12, 14*8(%r2)
	std  %f13, 15*8(%r2)
	std  %f14, 16*8(%r2)
	std  %f15, 17*8(%r2)

	lghi %r2, 0
	br   %r14
