.global fabs
.type fabs,@function
fabs:
	fldl 4(%esp)
	fabs
	ret
