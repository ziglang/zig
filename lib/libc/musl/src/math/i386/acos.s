# use acos(x) = atan2(fabs(sqrt((1-x)*(1+x))), x)

.global acos
.type acos,@function
acos:
	fldl 4(%esp)
	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fabs         # fix sign of zero (matters in downward rounding mode)
	fxch %st(1)
	fpatan
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
