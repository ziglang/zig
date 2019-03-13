.global llrint
.type llrint,@function
llrint:
	fldl 4(%esp)
	fistpll 4(%esp)
	mov 4(%esp),%eax
	mov 8(%esp),%edx
	ret
