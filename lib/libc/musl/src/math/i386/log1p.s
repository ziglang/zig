.global log1p
.type log1p,@function
log1p:
	mov 8(%esp),%eax
	fldln2
	and $0x7fffffff,%eax
	fldl 4(%esp)
	cmp $0x3fd28f00,%eax
	ja 1f
	cmp $0x00100000,%eax
	jb 2f
	fyl2xp1
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
1:	fld1
	faddp
	fyl2x
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
		# subnormal x, return x with underflow
2:	fsts 4(%esp)
	fstp %st(1)
	ret
