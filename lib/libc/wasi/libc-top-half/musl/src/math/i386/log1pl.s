.global log1pl
.type log1pl,@function
log1pl:
	mov 10(%esp),%eax
	fldln2
	and $0x7fffffff,%eax
	fldt 4(%esp)
	cmp $0x3ffd9400,%eax
	ja 1f
	fyl2xp1
	ret
1:	fld1
	faddp
	fyl2x
	ret
