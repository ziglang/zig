.global ldexpf
.type ldexpf,@function
ldexpf:
	nop

.global scalblnf
.type scalblnf,@function
scalblnf:
	nop

.global scalbnf
.type scalbnf,@function
scalbnf:
	mov 8(%esp),%eax
	add $0x3fe,%eax
	cmp $0x7fd,%eax
	jb 1f
	sub $0x3fe,%eax
	sar $31,%eax
	xor $0x1ff,%eax
	add $0x3fe,%eax
1:	inc %eax
	shl $20,%eax
	flds 4(%esp)
	mov %eax,8(%esp)
	xor %eax,%eax
	mov %eax,4(%esp)
	fldl 4(%esp)
	fmulp
	fstps 4(%esp)
	flds 4(%esp)
	ret
