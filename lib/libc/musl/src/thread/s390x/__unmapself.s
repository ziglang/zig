.text
.global __unmapself
.type   __unmapself, @function
__unmapself:
	svc 91 # SYS_munmap
	svc 1  # SYS_exit
