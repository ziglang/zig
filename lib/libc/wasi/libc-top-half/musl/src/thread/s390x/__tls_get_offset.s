	.global __tls_get_offset
	.type __tls_get_offset,%function
__tls_get_offset:
	stmg  %r14, %r15, 112(%r15)
	aghi  %r15, -160

	la    %r2, 0(%r2, %r12)
	brasl %r14, __tls_get_addr

	ear   %r1, %a0
	sllg  %r1, %r1, 32
	ear   %r1, %a1

	sgr   %r2, %r1

	lmg   %r14, %r15, 272(%r15)
	br    %r14
