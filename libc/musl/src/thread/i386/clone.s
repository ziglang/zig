.text
.global __clone
.hidden __clone
.type   __clone,@function
__clone:
	push %ebp
	mov %esp,%ebp
	push %ebx
	push %esi
	push %edi

	xor %eax,%eax
	push $0x51
	mov %gs,%ax
	push $0xfffff
	shr $3,%eax
	push 28(%ebp)
	push %eax
	mov $120,%al

	mov 12(%ebp),%ecx
	mov 16(%ebp),%ebx
	and $-16,%ecx
	sub $16,%ecx
	mov 20(%ebp),%edi
	mov %edi,(%ecx)
	mov 24(%ebp),%edx
	mov %esp,%esi
	mov 32(%ebp),%edi
	mov 8(%ebp),%ebp
	int $128
	test %eax,%eax
	jnz 1f

	mov %ebp,%eax
	xor %ebp,%ebp
	call *%eax
	mov %eax,%ebx
	xor %eax,%eax
	inc %eax
	int $128
	hlt

1:	add $16,%esp
	pop %edi
	pop %esi
	pop %ebx
	pop %ebp
	ret
