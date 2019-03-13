.set	noreorder
.global	__unmapself
.type	__unmapself,@function
__unmapself:
	li	$2, 6011
	syscall
	li	$4, 0
	li	$2, 6058
	syscall
