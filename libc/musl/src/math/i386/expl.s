# exp(x) = 2^hi + 2^hi (2^lo - 1)
# where hi+lo = log2e*x with 128bit precision
# exact log2e*x calculation depends on nearest rounding mode
# using the exact multiplication method of Dekker and Veltkamp

.global expl
.type expl,@function
expl:
	fldt 4(%esp)

		# interesting case: 0x1p-32 <= |x| < 16384
		# check if (exponent|0x8000) is in [0xbfff-32, 0xbfff+13]
	mov 12(%esp), %ax
	or $0x8000, %ax
	sub $0xbfdf, %ax
	cmp $45, %ax
	jbe 2f
	test %ax, %ax
	fld1
	js 1f
		# if |x|>=0x1p14 or nan return 2^trunc(x)
	fscale
	fstp %st(1)
	ret
		# if |x|<0x1p-32 return 1+x
1:	faddp
	ret

		# should be 0x1.71547652b82fe178p0L == 0x3fff b8aa3b29 5c17f0bc
		# it will be wrong on non-nearest rounding mode
2:	fldl2e
	subl $44, %esp
		# hi = log2e_hi*x
		# 2^hi = exp2l(hi)
	fmul %st(1),%st
	fld %st(0)
	fstpt (%esp)
	fstpt 16(%esp)
	fstpt 32(%esp)
.hidden __exp2l
	call __exp2l
		# if 2^hi == inf return 2^hi
	fld %st(0)
	fstpt (%esp)
	cmpw $0x7fff, 8(%esp)
	je 1f
	fldt 32(%esp)
	fldt 16(%esp)
		# fpu stack: 2^hi x hi
		# exact mult: x*log2e
	fld %st(1)
		# c = 0x1p32+1
	pushl $0x41f00000
	pushl $0x00100000
	fldl (%esp)
		# xh = x - c*x + c*x
		# xl = x - xh
	fmulp
	fld %st(2)
	fsub %st(1), %st
	faddp
	fld %st(2)
	fsub %st(1), %st
		# yh = log2e_hi - c*log2e_hi + c*log2e_hi
	pushl $0x3ff71547
	pushl $0x65200000
	fldl (%esp)
		# fpu stack: 2^hi x hi xh xl yh
		# lo = hi - xh*yh + xl*yh
	fld %st(2)
	fmul %st(1), %st
	fsubp %st, %st(4)
	fmul %st(1), %st
	faddp %st, %st(3)
		# yl = log2e_hi - yh
	pushl $0x3de705fc
	pushl $0x2f000000
	fldl (%esp)
		# fpu stack: 2^hi x lo xh xl yl
		# lo += xh*yl + xl*yl
	fmul %st, %st(2)
	fmulp %st, %st(1)
	fxch %st(2)
	faddp
	faddp
		# log2e_lo
	pushl $0xbfbe
	pushl $0x82f0025f
	pushl $0x2dc582ee
	fldt (%esp)
	addl $36,%esp
		# fpu stack: 2^hi x lo log2e_lo
		# lo += log2e_lo*x
		# return 2^hi + 2^hi (2^lo - 1)
	fmulp %st, %st(2)
	faddp
	f2xm1
	fmul %st(1), %st
	faddp
1:	addl $44, %esp
	ret
