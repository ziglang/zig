	nop
.global __restore_rt
.hidden __restore_rt
.type __restore_rt,@function
__restore_rt:
	mov $15, %rax
	syscall
.size __restore_rt,.-__restore_rt
