.global __syscall
.hidden __syscall
.type   __syscall,@function
__syscall:
	l.ori	r11, r3, 0
	l.lwz	r3, 0(r1)
	l.lwz	r4, 4(r1)
	l.lwz	r5, 8(r1)
	l.lwz	r6, 12(r1)
	l.lwz	r7, 16(r1)
	l.lwz	r8, 20(r1)
	l.sys	1
	l.jr	r9
	 l.nop
