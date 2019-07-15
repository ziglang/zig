.global _longjmp
.global longjmp
.type _longjmp,@function
.type longjmp,@function
_longjmp:
longjmp:
	mov  4(%esp),%edx
	mov  8(%esp),%eax
	test    %eax,%eax
	jnz 1f
	inc     %eax
1:
	mov   (%edx),%ebx
	mov  4(%edx),%esi
	mov  8(%edx),%edi
	mov 12(%edx),%ebp
	mov 16(%edx),%ecx
	mov     %ecx,%esp
	mov 20(%edx),%ecx
	jmp *%ecx
