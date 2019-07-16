.global _longjmp
.global longjmp
.type   _longjmp,@function
.type   longjmp,@function
_longjmp:
longjmp:
	addi    r3, r6, 0
	bnei    r3, 1f
	addi    r3, r3, 1
1:      lwi     r1,  r5, 0
	lwi     r15, r5, 4
	lwi     r2,  r5, 8
	lwi     r13, r5, 12
	lwi     r18, r5, 16
	lwi     r19, r5, 20
	lwi     r20, r5, 24
	lwi     r21, r5, 28
	lwi     r22, r5, 32
	lwi     r23, r5, 36
	lwi     r24, r5, 40
	lwi     r25, r5, 44
	lwi     r26, r5, 48
	lwi     r27, r5, 52
	lwi     r28, r5, 56
	lwi     r29, r5, 60
	lwi     r30, r5, 64
	lwi     r31, r5, 68
	rtsd    r15, 8
	nop
