.global __clone
.hidden __clone
.type   __clone,@function

# r5, r6, r7, r8, r9, r10, stack
# fn, st, fl, ar, pt, tl, ct
# fl, st, __, pt, ct, tl

__clone:
	andi    r6, r6, -16
	addi    r6, r6, -16
	swi     r5, r6, 0
	swi     r8, r6, 4

	ori     r5, r7, 0
	ori     r8, r9, 0
	lwi     r9, r1, 28
	ori     r12, r0, 120

	brki    r14, 8
	beqi	r3, 1f
	rtsd    r15, 8
	nop

1:	lwi     r3, r1, 0
	lwi     r5, r1, 4
	brald   r15, r3
	nop
	ori     r12, r0, 1
	brki    r14, 8
