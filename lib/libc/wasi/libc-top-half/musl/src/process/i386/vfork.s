.global vfork
.type vfork,@function
vfork:
	pop %edx
	mov $190,%eax
	int $128
	push %edx
	push %eax
	.hidden __syscall_ret
	call __syscall_ret
	pop %edx
	ret
