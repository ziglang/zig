.global acosf
.type acosf,@function
acosf:
	flds 4(%esp)
	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fabs         # fix sign of zero (matters in downward rounding mode)
	fxch %st(1)
	fpatan
	fstps 4(%esp)
	flds 4(%esp)
	ret
