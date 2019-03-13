.global asinf
.type asinf,@function
asinf:
	flds 4(%esp)
	mov 4(%esp),%eax
	add %eax,%eax
	cmp $0x01000000,%eax
	jae 1f
		# subnormal x, return x with underflow
	fnstsw %ax
	and $16,%ax
	jnz 2f
	fld %st(0)
	fmul %st(1)
	fstps 4(%esp)
2:	ret

.global asinl
.type asinl,@function
asinl:
	fldt 4(%esp)
	jmp 1f

.global asin
.type asin,@function
asin:
	fldl 4(%esp)
	mov 8(%esp),%eax
	add %eax,%eax
	cmp $0x00200000,%eax
	jae 1f
		# subnormal x, return x with underflow
	fnstsw %ax
	and $16,%ax
	jnz 2f
	fsts 4(%esp)
2:	ret
1:	fld %st(0)
	fld1
	fsub %st(0),%st(1)
	fadd %st(2)
	fmulp
	fsqrt
	fpatan
	ret
