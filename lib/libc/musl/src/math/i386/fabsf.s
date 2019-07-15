.global fabsf
.type fabsf,@function
fabsf:
	flds 4(%esp)
	fabs
	ret
