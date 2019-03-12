.text
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,@function
__tlsdesc_static:
	mov 4(%eax),%eax
	ret

.hidden __tls_get_new

.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	mov 4(%eax),%eax
	push %edx
	mov %gs:4,%edx
	push %ecx
	mov (%eax),%ecx
	cmp %ecx,(%edx)
	jc 1f
	mov 4(%eax),%eax
	add (%edx,%ecx,4),%eax
2:	pop %ecx
	sub %gs:0,%eax
	pop %edx
	ret
1:	push %eax
	call __tls_get_new
	pop %ecx
	jmp 2b
