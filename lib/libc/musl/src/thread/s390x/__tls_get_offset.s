	.global __tls_get_offset
	.type __tls_get_offset,%function
__tls_get_offset:
	ear   %r0, %a0
	sllg  %r0, %r0, 32
	ear   %r0, %a1

	la    %r1, 0(%r2, %r12)

	lg    %r3, 0(%r1)
	sllg  %r4, %r3, 3
	lg    %r5, 8(%r0)
	lg    %r2, 0(%r4, %r5)
	ag    %r2, 8(%r1)
	sgr   %r2, %r0

	br    %r14
