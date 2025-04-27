#include <syscall.h>

.global __unmapself
.type   __unmapself,%function
__unmapself:
	r6 = #215			// SYS_munmap
	trap0(#1)
	r6 = #93			// SYS_exit
	trap0(#1)
	jumpr r31
.size __unmapself, .-__unmapself
