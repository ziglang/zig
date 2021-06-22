.global asinf
.type asinf,@function
asinf:
	flds 4(%esp)
	mov 4(%esp),%eax
	add %eax,%eax
	cmp $0x01000000,%eax
	jb 1f
	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fpatan
	fstps 4(%esp)
	flds 4(%esp)
	ret
		# subnormal x, return x with underflow
1:	fld %st(0)
	fmul %st(1)
	fstps 4(%esp)
	ret
