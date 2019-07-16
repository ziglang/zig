.global expm1l
.type expm1l,@function
expm1l:
	fldt 8(%esp)
	fldl2e
	fmulp
	movl $0xc2820000,-4(%esp)
	flds -4(%esp)
	fucomip %st(1),%st
	fld1
	jb 1f
		# x*log2e <= -65, return -1 without underflow
	fstp %st(1)
	fchs
	ret
1:	fld %st(1)
	fabs
	fucomip %st(1),%st
	fstp %st(0)
	ja 1f
	f2xm1
	ret
1:	push %rax
	call 1f
	pop %rax
	fld1
	fsubrp
	ret

.global exp2l
.type exp2l,@function
exp2l:
	fldt 8(%esp)
1:	fld %st(0)
	sub $16,%esp
	fstpt (%esp)
	mov 8(%esp),%ax
	and $0x7fff,%ax
	cmp $0x3fff+13,%ax
	jb 4f             # |x| < 8192
	cmp $0x3fff+15,%ax
	jae 3f            # |x| >= 32768
	fsts (%esp)
	cmpl $0xc67ff800,(%esp)
	jb 2f             # x > -16382
	movl $0x5f000000,(%esp)
	flds (%esp)       # 0x1p63
	fld %st(1)
	fsub %st(1)
	faddp
	fucomip %st(1),%st
	je 2f             # x - 0x1p63 + 0x1p63 == x
	movl $1,(%esp)
	flds (%esp)       # 0x1p-149
	fdiv %st(1)
	fstps (%esp)      # raise underflow
2:	fld1
	fld %st(1)
	frndint
	fxch %st(2)
	fsub %st(2)       # st(0)=x-rint(x), st(1)=1, st(2)=rint(x)
	f2xm1
	faddp             # 2^(x-rint(x))
1:	fscale
	fstp %st(1)
	add $16,%esp
	ret
3:	xor %eax,%eax
4:	cmp $0x3fff-64,%ax
	fld1
	jb 1b             # |x| < 0x1p-64
	fstpt (%esp)
	fistl 8(%esp)
	fildl 8(%esp)
	fsubrp %st(1)
	addl $0x3fff,8(%esp)
	f2xm1
	fld1
	faddp             # 2^(x-rint(x))
	fldt (%esp)       # 2^rint(x)
	fmulp
	add $16,%esp
	ret
