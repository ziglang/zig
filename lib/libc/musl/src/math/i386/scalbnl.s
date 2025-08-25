.global ldexpl
.type ldexpl,@function
ldexpl:
	nop

.global scalblnl
.type scalblnl,@function
scalblnl:
	nop

.global scalbnl
.type scalbnl,@function
scalbnl:
	mov 16(%esp),%eax
	add $0x3ffe,%eax
	cmp $0x7ffd,%eax
	jae 1f
	inc %eax
	fldt 4(%esp)
	mov %eax,12(%esp)
	mov $0x80000000,%eax
	mov %eax,8(%esp)
	xor %eax,%eax
	mov %eax,4(%esp)
	fldt 4(%esp)
	fmulp
	ret
1:	fildl 16(%esp)
	fldt 4(%esp)
	fscale
	fstp %st(1)
	ret
