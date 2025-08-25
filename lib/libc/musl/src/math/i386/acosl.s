.global acosl
.type acosl,@function
acosl:
	fldt 4(%esp)
	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fabs         # fix sign of zero (matters in downward rounding mode)
	fxch %st(1)
	fpatan
	ret
