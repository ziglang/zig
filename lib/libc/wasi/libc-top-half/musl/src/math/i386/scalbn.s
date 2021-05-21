.global ldexp
.type ldexp,@function
ldexp:
	nop

.global scalbln
.type scalbln,@function
scalbln:
	nop

.global scalbn
.type scalbn,@function
scalbn:
	mov 12(%esp),%eax
	add $0x3ffe,%eax
	cmp $0x7ffd,%eax
	jb 1f
	sub $0x3ffe,%eax
	sar $31,%eax
	xor $0xfff,%eax
	add $0x3ffe,%eax
1:	inc %eax
	fldl 4(%esp)
	mov %eax,12(%esp)
	mov $0x80000000,%eax
	mov %eax,8(%esp)
	xor %eax,%eax
	mov %eax,4(%esp)
	fldt 4(%esp)
	fmulp
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
