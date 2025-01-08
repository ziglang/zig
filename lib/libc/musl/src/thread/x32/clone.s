.text
.global __clone
.hidden __clone
.type   __clone,@function
__clone:
	movl $0x40000038,%eax /* SYS_clone */
	mov %rdi,%r11
	mov %rdx,%rdi
	mov %r8,%rdx
	mov %r9,%r8
	mov 8(%rsp),%r10
	mov %r11,%r9
	and $-16,%rsi
	sub $8,%rsi
	mov %rcx,(%rsi)
	syscall
	test %eax,%eax
	jz 1f
	ret
1:	xor %ebp,%ebp
	pop %rdi
	call *%r9
	mov %eax,%edi
	movl $0x4000003c,%eax /* SYS_exit */
	syscall
	hlt
