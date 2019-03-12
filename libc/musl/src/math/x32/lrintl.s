.global lrintl
.type lrintl,@function
lrintl:
	fldt 8(%esp)
	fistpll 8(%esp)
	mov 8(%esp),%rax
	ret
