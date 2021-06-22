.global vfork
.type vfork,@function
vfork:
	pop %rdx
	mov $0x4000003a,%eax /* SYS_vfork */
	syscall
	push %rdx
	mov %rax,%rdi
	.hidden __syscall_ret
	jmp __syscall_ret
