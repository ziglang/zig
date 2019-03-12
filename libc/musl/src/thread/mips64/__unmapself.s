.set	noreorder
.global	__unmapself
.type	__unmapself, @function
__unmapself:
	li	$2, 5011
	syscall
	li	$4, 0
	li	$2, 5058
	syscall
