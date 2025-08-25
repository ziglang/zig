.global ___setjmp
.hidden ___setjmp
.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp,@function
.type _setjmp,@function
.type setjmp,@function
___setjmp:
__setjmp:
_setjmp:
setjmp:
	mov 4(%esp), %eax
	mov    %ebx, (%eax)
	mov    %esi, 4(%eax)
	mov    %edi, 8(%eax)
	mov    %ebp, 12(%eax)
	lea 4(%esp), %ecx
	mov    %ecx, 16(%eax)
	mov  (%esp), %ecx
	mov    %ecx, 20(%eax)
	xor    %eax, %eax
	ret
