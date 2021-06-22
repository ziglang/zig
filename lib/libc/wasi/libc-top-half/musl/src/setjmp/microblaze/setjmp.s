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
	swi     r1,  r5, 0
	swi     r15, r5, 4
	swi     r2,  r5, 8
	swi     r13, r5, 12
	swi     r18, r5, 16
	swi     r19, r5, 20
	swi     r20, r5, 24
	swi     r21, r5, 28
	swi     r22, r5, 32
	swi     r23, r5, 36
	swi     r24, r5, 40
	swi     r25, r5, 44
	swi     r26, r5, 48
	swi     r27, r5, 52
	swi     r28, r5, 56
	swi     r29, r5, 60
	swi     r30, r5, 64
	swi     r31, r5, 68
	rtsd    r15, 8
	ori     r3, r0, 0
