.global hypot
.type hypot,@function
hypot:
	mov 8(%esp),%eax
	mov 16(%esp),%ecx
	add %eax,%eax
	add %ecx,%ecx
	and %eax,%ecx
	cmp $0xffe00000,%ecx
	jae 2f
	or 4(%esp),%eax
	jnz 1f
	fldl 12(%esp)
	fabs
	ret
1:	mov 16(%esp),%eax
	add %eax,%eax
	or 12(%esp),%eax
	jnz 1f
	fldl 4(%esp)
	fabs
	ret
1:	fldl 4(%esp)
	fld %st(0)
	fmulp
	fldl 12(%esp)
	fld %st(0)
	fmulp
	faddp
	fsqrt
	ret
2:	sub $0xffe00000,%eax
	or 4(%esp),%eax
	jnz 1f
	fldl 4(%esp)
	fabs
	ret
1:	mov 16(%esp),%eax
	add %eax,%eax
	sub $0xffe00000,%eax
	or 12(%esp),%eax
	fldl 12(%esp)
	jnz 1f
	fabs
1:	ret
