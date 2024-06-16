.global __unmapself
.type   __unmapself, @function
__unmapself:
	li.d    $a7, 215   # call munmap
	syscall 0
	li.d    $a7, 93    # call exit
	syscall 0
