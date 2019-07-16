.syntax unified
.global vfork
.type vfork,%function
vfork:
	mov ip, r7
	mov r7, 190
	svc 0
	mov r7, ip
	.hidden __syscall_ret
	b __syscall_ret
