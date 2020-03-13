.global atan2
.type atan2,@function
atan2:
	fldl 4(%esp)
	fldl 12(%esp)
	fpatan
	fstpl 4(%esp)
	fldl 4(%esp)
	mov 8(%esp),%eax
	add %eax,%eax
	cmp $0x00200000,%eax
	jae 1f
		# subnormal x, return x with underflow
	fsts 4(%esp)
1:	ret
