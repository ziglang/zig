# see ../i386/acos.s

.global acosl
.type acosl,@function
acosl:
	fldt 8(%rsp)
1:	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fabs
	fxch %st(1)
	fpatan
	ret
