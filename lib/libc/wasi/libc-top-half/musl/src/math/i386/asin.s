.global asin
.type asin,@function
asin:
	fldl 4(%esp)
	mov 8(%esp),%eax
	add %eax,%eax
	cmp $0x00200000,%eax
	jb 1f
	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fpatan
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
		# subnormal x, return x with underflow
1:	fsts 4(%esp)
	ret
