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
1:	fsts 4(%esp)
	ret
