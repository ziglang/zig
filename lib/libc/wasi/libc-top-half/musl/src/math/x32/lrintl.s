.global lrintl
.type lrintl,@function
lrintl:
	fldt 8(%esp)
	fistpl 8(%esp)
	movl 8(%esp),%eax
	ret
