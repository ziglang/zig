.global logf
.type logf,@function
logf:
	fldln2
	flds 4(%esp)
	fyl2x
	fstps 4(%esp)
	flds 4(%esp)
	ret
