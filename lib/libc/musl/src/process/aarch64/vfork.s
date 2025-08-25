.global vfork
.type vfork,%function
vfork:
	mov x8, 220    // SYS_clone
	mov x0, 0x4111 // SIGCHLD | CLONE_VM | CLONE_VFORK
	mov x1, 0
	svc 0
	.hidden __syscall_ret
	b __syscall_ret
