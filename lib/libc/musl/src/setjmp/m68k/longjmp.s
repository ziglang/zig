.global _longjmp
.global longjmp
.type _longjmp,@function
.type longjmp,@function
_longjmp:
longjmp:
	movea.l 4(%sp),%a0
	move.l 8(%sp),%d0
	bne 1f
	move.l #1,%d0
1:	movem.l (%a0),%d2-%d7/%a2-%a7
	fmovem.x 52(%a0),%fp2-%fp7
	move.l 48(%a0),(%sp)
	rts
