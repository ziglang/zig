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
	l.sw	0(r3), r1
	l.sw	4(r3), r2
	l.sw	8(r3), r9
	l.sw	12(r3), r10
	l.sw	16(r3), r14
	l.sw	20(r3), r16
	l.sw	24(r3), r18
	l.sw	28(r3), r20
	l.sw	32(r3), r22
	l.sw	36(r3), r24
	l.sw	40(r3), r26
	l.sw	44(r3), r28
	l.sw	48(r3), r30
	l.jr	r9
	 l.ori	r11,r0,0
