.global hypotf
.type hypotf,@function
hypotf:
	mov 4(%esp),%eax
	mov 8(%esp),%ecx
	add %eax,%eax
	add %ecx,%ecx
	and %eax,%ecx
	cmp $0xff000000,%ecx
	jae 2f
	test %eax,%eax
	jnz 1f
	flds 8(%esp)
	fabs
	ret
1:	mov 8(%esp),%eax
	add %eax,%eax
	jnz 1f
	flds 4(%esp)
	fabs
	ret
1:	flds 4(%esp)
	fld %st(0)
	fmulp
	flds 8(%esp)
	fld %st(0)
	fmulp
	faddp
	fsqrt
	ret
2:	cmp $0xff000000,%eax
	jnz 1f
	flds 4(%esp)
	fabs
	ret
1:	mov 8(%esp),%eax
	add %eax,%eax
	cmp $0xff000000,%eax
	flds 8(%esp)
	jnz 1f
	fabs
1:	ret
