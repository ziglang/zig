.global logl
.type logl,@function
logl:
	fldln2
	fldt 8(%esp)
	fyl2x
	ret
