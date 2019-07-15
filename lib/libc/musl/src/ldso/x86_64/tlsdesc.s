.text
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,@function
__tlsdesc_static:
	mov 8(%rax),%rax
	ret

.hidden __tls_get_new

.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	mov 8(%rax),%rax
	push %rdx
	mov %fs:8,%rdx
	push %rcx
	mov (%rax),%rcx
	cmp %rcx,(%rdx)
	jc 1f
	mov 8(%rax),%rax
	add (%rdx,%rcx,8),%rax
2:	pop %rcx
	sub %fs:0,%rax
	pop %rdx
	ret
1:	push %rdi
	push %rdi
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11
	mov %rax,%rdi
	call __tls_get_new
	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rdi
	pop %rdi
	jmp 2b
