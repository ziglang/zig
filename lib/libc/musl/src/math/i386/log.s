.global log
.type log,@function
log:
	fldln2
	fldl 4(%esp)
	fyl2x
	ret
