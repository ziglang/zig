.global logl
.type logl,@function
logl:
	fldln2
	fldt 4(%esp)
	fyl2x
	ret
