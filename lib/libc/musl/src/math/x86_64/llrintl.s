.global llrintl
.type llrintl,@function
llrintl:
	fldt 8(%rsp)
	fistpll 8(%rsp)
	mov 8(%rsp),%rax
	ret
