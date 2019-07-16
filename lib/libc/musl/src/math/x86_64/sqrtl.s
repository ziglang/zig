.global sqrtl
.type sqrtl,@function
sqrtl:	fldt 8(%rsp)
	fsqrt
	ret
