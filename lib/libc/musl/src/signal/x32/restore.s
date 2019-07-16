	nop
.global __restore_rt
.hidden __restore_rt
.type __restore_rt,@function
__restore_rt:
	mov $0x40000201, %rax /* SYS_rt_sigreturn */
	syscall
.size __restore_rt,.-__restore_rt
