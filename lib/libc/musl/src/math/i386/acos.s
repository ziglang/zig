# use acos(x) = atan2(fabs(sqrt((1-x)*(1+x))), x)

.global acosf
.type acosf,@function
acosf:
	flds 4(%esp)
	jmp 1f

.global acosl
.type acosl,@function
acosl:
	fldt 4(%esp)
	jmp 1f

.global acos
.type acos,@function
acos:
	fldl 4(%esp)
1:	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fabs         # fix sign of zero (matters in downward rounding mode)
	fxch %st(1)
	fpatan
	ret
