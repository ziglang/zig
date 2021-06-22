.global memset
.type memset,@function
memset:
	movzbq %sil,%rax
	mov $0x101010101010101,%r8
	imul %r8,%rax

	cmp $126,%rdx
	ja 2f

	test %edx,%edx
	jz 1f

	mov %sil,(%rdi)
	mov %sil,-1(%rdi,%rdx)
	cmp $2,%edx
	jbe 1f

	mov %ax,1(%rdi)
	mov %ax,(-1-2)(%rdi,%rdx)
	cmp $6,%edx
	jbe 1f

	mov %eax,(1+2)(%rdi)
	mov %eax,(-1-2-4)(%rdi,%rdx)
	cmp $14,%edx
	jbe 1f

	mov %rax,(1+2+4)(%rdi)
	mov %rax,(-1-2-4-8)(%rdi,%rdx)
	cmp $30,%edx
	jbe 1f

	mov %rax,(1+2+4+8)(%rdi)
	mov %rax,(1+2+4+8+8)(%rdi)
	mov %rax,(-1-2-4-8-16)(%rdi,%rdx)
	mov %rax,(-1-2-4-8-8)(%rdi,%rdx)
	cmp $62,%edx
	jbe 1f

	mov %rax,(1+2+4+8+16)(%rdi)
	mov %rax,(1+2+4+8+16+8)(%rdi)
	mov %rax,(1+2+4+8+16+16)(%rdi)
	mov %rax,(1+2+4+8+16+24)(%rdi)
	mov %rax,(-1-2-4-8-16-32)(%rdi,%rdx)
	mov %rax,(-1-2-4-8-16-24)(%rdi,%rdx)
	mov %rax,(-1-2-4-8-16-16)(%rdi,%rdx)
	mov %rax,(-1-2-4-8-16-8)(%rdi,%rdx)

1:	mov %rdi,%rax
	ret

2:	test $15,%edi
	mov %rdi,%r8
	mov %rax,-8(%rdi,%rdx)
	mov %rdx,%rcx
	jnz 2f

1:	shr $3,%rcx
	rep
	stosq
	mov %r8,%rax
	ret

2:	xor %edx,%edx
	sub %edi,%edx
	and $15,%edx
	mov %rax,(%rdi)
	mov %rax,8(%rdi)
	sub %rdx,%rcx
	add %rdx,%rdi
	jmp 1b
