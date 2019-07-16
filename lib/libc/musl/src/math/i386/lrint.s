.global lrint
.type lrint,@function
lrint:
	fldl 4(%esp)
	fistpl 4(%esp)
	mov 4(%esp),%eax
	ret
