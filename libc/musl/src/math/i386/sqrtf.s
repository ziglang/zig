.global sqrtf
.type sqrtf,@function
sqrtf:	flds 4(%esp)
	fsqrt
	fstps 4(%esp)
	flds 4(%esp)
	ret
