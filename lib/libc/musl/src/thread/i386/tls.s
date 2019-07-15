.text
.global ___tls_get_addr
.type ___tls_get_addr,@function
___tls_get_addr:
	mov %gs:4,%edx
	mov (%eax),%ecx
	cmp %ecx,(%edx)
	jc 1f
	mov 4(%eax),%eax
	add (%edx,%ecx,4),%eax
	ret
1:	push %eax
.weak __tls_get_new
.hidden __tls_get_new
	call __tls_get_new
	pop %edx
	ret
