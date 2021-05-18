	.global vfork
	.type vfork,%function
vfork:
	svc 190
	.hidden __syscall_ret
	jg  __syscall_ret
