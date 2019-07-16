.global atan
.type atan,@function
atan:
	fldl 4(%esp)
	mov 8(%esp),%eax
	add %eax,%eax
	cmp $0x00200000,%eax
	jb 1f
	fld1
	fpatan
	ret
		# subnormal x, return x with underflow
1:	fnstsw %ax
	and $16,%ax
	jnz 2f
	fsts 4(%esp)
2:	ret
