.global fabsl
.type fabsl,@function
fabsl:
	fldt 8(%esp)
	fabs
	ret
