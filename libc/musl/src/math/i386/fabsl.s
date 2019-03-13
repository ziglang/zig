.global fabsl
.type fabsl,@function
fabsl:
	fldt 4(%esp)
	fabs
	ret
