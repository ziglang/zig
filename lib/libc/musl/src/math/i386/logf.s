.global logf
.type logf,@function
logf:
	fldln2
	flds 4(%esp)
	fyl2x
	ret
