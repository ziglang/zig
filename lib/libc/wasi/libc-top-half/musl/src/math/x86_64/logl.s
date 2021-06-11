.global logl
.type logl,@function
logl:
	fldln2
	fldt 8(%rsp)
	fyl2x
	ret
