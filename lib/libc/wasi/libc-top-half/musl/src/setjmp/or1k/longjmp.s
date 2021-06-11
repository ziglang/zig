.global _longjmp
.global longjmp
.type   _longjmp,@function
.type   longjmp,@function
_longjmp:
longjmp:
	l.sfeqi	r4, 0
	l.bnf	1f
	 l.addi	r11, r4,0
	l.ori	r11, r0, 1
1:	l.lwz	r1, 0(r3)
	l.lwz	r2, 4(r3)
	l.lwz	r9, 8(r3)
	l.lwz	r10, 12(r3)
	l.lwz	r14, 16(r3)
	l.lwz	r16, 20(r3)
	l.lwz	r18, 24(r3)
	l.lwz	r20, 28(r3)
	l.lwz	r22, 32(r3)
	l.lwz	r24, 36(r3)
	l.lwz	r26, 40(r3)
	l.lwz	r28, 44(r3)
	l.lwz	r30, 48(r3)
	l.jr	r9
	 l.nop
