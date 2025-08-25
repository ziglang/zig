.global ___setjmp
.hidden ___setjmp
.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp,@function
.type _setjmp,@function
.type setjmp,@function
___setjmp:
__setjmp:
_setjmp:
setjmp:
	movea.l 4(%sp),%a0
	movem.l %d2-%d7/%a2-%a7,(%a0)
	move.l (%sp),48(%a0)
	fmovem.x %fp2-%fp7,52(%a0)
	clr.l %d0
	rts
