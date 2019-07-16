.text
.global __unmapself
.type   __unmapself,@function
__unmapself:
	movl $91,%eax
	movl 4(%esp),%ebx
	movl 8(%esp),%ecx
	int $128
	xorl %ebx,%ebx
	movl $1,%eax
	int $128
