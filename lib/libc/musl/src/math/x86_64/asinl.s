.global asinl
.type asinl,@function
asinl:
	fldt 8(%rsp)
1:	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fpatan
	ret
