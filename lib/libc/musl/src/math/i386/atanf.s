.global atanf
.type atanf,@function
atanf:
	flds 4(%esp)
	mov 4(%esp),%eax
	add %eax,%eax
	cmp $0x01000000,%eax
	jb 1f
	fld1
	fpatan
	ret
		# subnormal x, return x with underflow
1:	fld %st(0)
	fmul %st(1)
	fstps 4(%esp)
	ret
