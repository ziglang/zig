/* Copyright 2011-2012 Nicholas J. Kain, licensed under standard MIT license */
.text
.global __unmapself
.type   __unmapself,@function
__unmapself:
	movl $0x4000000b,%eax   /* SYS_munmap */
	syscall         /* munmap(arg2,arg3) */
	xor %rdi,%rdi   /* exit() args: always return success */
	movl $0x4000003c,%eax   /* SYS_exit */
	syscall         /* exit(0) */
