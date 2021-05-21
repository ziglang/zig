/* int clone(fn, stack, flags, arg, ptid, tls, ctid)
 *           r3  r4     r5     r6   sp+0  sp+4 sp+8
 * sys_clone(flags, stack, ptid, ctid, tls)
 */
.global __clone
.hidden __clone
.type   __clone,@function
__clone:
	l.addi	r4, r4, -8
	l.sw	0(r4), r3
	l.sw	4(r4), r6
	/* (fn, st, fl, ar, pt, tl, ct) => (fl, st, pt, ct, tl) */
	l.ori	r3, r5, 0
	l.lwz	r5, 0(r1)
	l.lwz	r6, 8(r1)
	l.lwz	r7, 4(r1)
	l.ori	r11, r0, 220 /* __NR_clone */
	l.sys	1

	l.sfeqi	r11, 0
	l.bf	1f
	 l.nop
	l.jr	r9
	 l.nop

1:	l.lwz	r11, 0(r1)
	l.jalr	r11
	 l.lwz	r3, 4(r1)

	l.ori	r11, r0, 93 /* __NR_exit */
	l.sys	1
