.global atan2f
.type atan2f,@function
atan2f:
	flds 4(%esp)
	flds 8(%esp)
	fpatan
	fsts 4(%esp)
	mov 4(%esp),%eax
	add %eax,%eax
	cmp $0x01000000,%eax
	jae 1f
		# subnormal x, return x with underflow
	fld %st(0)
	fmul %st(1)
	fstps 4(%esp)
1:	ret
