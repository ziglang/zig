	.global __tls_get_offset
	.type __tls_get_offset,%function
__tls_get_offset:
	ear   %r3, %a0
	sllg  %r3, %r3, 32
	ear   %r3, %a1

	la    %r1, 0(%r2, %r12)

	lg    %r0, 0(%r1)
	sllg  %r4, %r0, 3
	lg    %r5, 8(%r3)
	lg    %r2, 0(%r4, %r5)
	ag    %r2, 8(%r1)
	sgr   %r2, %r3

	br    %r14
