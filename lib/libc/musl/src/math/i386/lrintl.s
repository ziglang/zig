.global lrintl
.type lrintl,@function
lrintl:
	fldt 4(%esp)
	fistpl 4(%esp)
	mov 4(%esp),%eax
	ret
