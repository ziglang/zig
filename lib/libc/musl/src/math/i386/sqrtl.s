.global sqrtl
.type sqrtl,@function
sqrtl:	fldt 4(%esp)
	fsqrt
	ret
