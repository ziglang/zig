.text
.global ___tls_get_addr
.type ___tls_get_addr,@function
___tls_get_addr:
	mov %gs:4,%edx
	mov (%eax),%ecx
	mov 4(%eax),%eax
	add (%edx,%ecx,4),%eax
	ret
