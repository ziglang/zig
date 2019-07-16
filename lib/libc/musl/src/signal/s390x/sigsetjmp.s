	.global sigsetjmp
	.global __sigsetjmp
	.type sigsetjmp,%function
	.type __sigsetjmp,%function
	.hidden ___setjmp
sigsetjmp:
__sigsetjmp:
	ltgr  %r3, %r3
	jz    ___setjmp

	stg   %r14, 18*8(%r2)
	stg   %r6,  20*8(%r2)
	lgr   %r6,  %r2

	brasl %r14, ___setjmp

	lgr   %r3,  %r2
	lgr   %r2,  %r6
	lg    %r14, 18*8(%r2)
	lg    %r6,  20*8(%r2)

.hidden __sigsetjmp_tail
	jg __sigsetjmp_tail
