.text
.global __clone
.hidden __clone
.type   __clone,@function
__clone:
	movem.l %d2-%d5,-(%sp)
	move.l #120,%d0
	move.l 28(%sp),%d1
	move.l 24(%sp),%d2
	and.l #-16,%d2
	move.l 36(%sp),%d3
	move.l 44(%sp),%d4
	move.l 40(%sp),%d5
	move.l 20(%sp),%a0
	move.l 32(%sp),%a1
	trap #0
	tst.l %d0
	beq 1f
	movem.l (%sp)+,%d2-%d5
	rts
1:	move.l %a1,-(%sp)
	jsr (%a0)
	move.l #1,%d0
	trap #0
	clr.b 0
