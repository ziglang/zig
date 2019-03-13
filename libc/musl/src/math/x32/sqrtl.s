.global sqrtl
.type sqrtl,@function
sqrtl:	fldt 8(%esp)
	fsqrt
	ret
