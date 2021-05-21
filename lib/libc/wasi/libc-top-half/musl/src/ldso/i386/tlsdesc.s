.text
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,@function
__tlsdesc_static:
	mov 4(%eax),%eax
	ret

.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	mov 4(%eax),%eax
	push %edx
	mov %gs:4,%edx
	push %ecx
	mov (%eax),%ecx
	mov 4(%eax),%eax
	add (%edx,%ecx,4),%eax
	pop %ecx
	sub %gs:0,%eax
	pop %edx
	ret
