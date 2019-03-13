.global llrintl
.type llrintl,@function
llrintl:
	fldt 8(%esp)
	fistpll 8(%esp)
	mov 8(%esp),%rax
	ret
