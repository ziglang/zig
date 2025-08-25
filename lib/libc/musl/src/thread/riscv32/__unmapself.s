.global __unmapself
.type __unmapself, %function
__unmapself:
	li a7, 215 # SYS_munmap
	ecall
	li a7, 93  # SYS_exit
	ecall
