.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp, %function
.type __sigsetjmp, %function
sigsetjmp:
__sigsetjmp:
	bnez a1, 1f
	tail setjmp
1:

	sd ra, 208(a0)
	sd s0, 224(a0)
	mv s0, a0

	call setjmp

	mv a1, a0
	mv a0, s0
	ld s0, 224(a0)
	ld ra, 208(a0)

.hidden __sigsetjmp_tail
	tail __sigsetjmp_tail
