.syntax unified
.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,%function
.type __sigsetjmp,%function
sigsetjmp:
__sigsetjmp:
	tst r1,r1
	bne 1f
	b setjmp

1:	str lr,[r0,#256]
	str r4,[r0,#260+8]
	mov r4,r0

	bl setjmp

	mov r1,r0
	mov r0,r4
	ldr lr,[r0,#256]
	ldr r4,[r0,#260+8]

.hidden __sigsetjmp_tail
	b __sigsetjmp_tail
