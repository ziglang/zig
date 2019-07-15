.global lrintf
.type lrintf,@function
lrintf:
	flds 4(%esp)
	fistpl 4(%esp)
	mov 4(%esp),%eax
	ret
