/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

/*
 * frexpl(long double x, int* expnt) extracts the exponent from x.
 * It returns an integer power of two to expnt and the significand
 * between 0.5 and 1 to y.  Thus  x = y * 2**expn.
 */ 
#ifdef __x86_64__
	.align 8
#else
	.align 2
#endif
.globl __MINGW_USYMBOL(frexpl)
__MINGW_USYMBOL(frexpl):
#ifdef __x86_64__
	pushq %rbp
	movq %rsp,%rbp
	subq $48,%rsp
	pushq %rsi
	fldt (%rdx)
	movq %rcx,%r9
	fld %st(0)
	fstpt -12(%rbp)
	leaq -4(%rbp),%rcx
	movw -4(%rbp),%dx
	andl $32767,%edx
	jne L25
	fldz
	fucompp
	fnstsw %ax
	andb $68,%ah
	xorb $64,%ah
	jne L21
	movl $0,(%r8)
	fldz
	jmp L24
	.align 4,0x90
	.align 4,0x90
L21:
	fldt -12(%rbp)
	fadd %st(0),%st
	fstpt -12(%rbp)
	decl %edx
	movw (%rcx),%si
	andl $32767,%esi
	jne L22
	cmpl $-66,%edx
	jg L21
L22:
	add %esi,%edx
	jmp L19
	.align 2,0x90
L25:
	fstp %st(0)
L19:
	addl $-16382,%edx
	movl %edx,(%r8)
	movw (%rcx),%ax
	andl $-32768,%eax
	orl $16382,%eax
	movw %ax,(%rcx)
	fldt -12(%rbp)
L24:
	popq %rsi
	movq	%r9,%rax
	movq	$0,8(%r9)
	fstpt	(%r9)
	leave
	ret
#else
	pushl %ebp
	movl %esp,%ebp
	subl $24,%esp
	pushl %esi
	pushl %ebx
	fldt 8(%ebp)
	movl 20(%ebp),%ebx
	fld %st(0)
	fstpt -12(%ebp)
	leal -4(%ebp),%ecx
	movw -4(%ebp),%dx
	andl $32767,%edx
	jne L25
	fldz
	fucompp
	fnstsw %ax
	andb $68,%ah
	xorb $64,%ah
	jne L21
	movl $0,(%ebx)
	fldz
	jmp L24
	.align 2,0x90
	.align 2,0x90
L21:
	fldt -12(%ebp)
	fadd %st(0),%st
	fstpt -12(%ebp)
	decl %edx
	movw (%ecx),%si
	andl $32767,%esi
	jne L22
	cmpl $-66,%edx
	jg L21
L22:
	addl %esi,%edx
	jmp L19
	.align 2,0x90
L25:
	fstp %st(0)
L19:
	addl $-16382,%edx
	movl %edx,(%ebx)
	movw (%ecx),%ax
	andl $-32768,%eax
	orl $16382,%eax
	movw %ax,(%ecx)
	fldt -12(%ebp)
L24:
	leal -32(%ebp),%esp
	popl %ebx
	popl %esi
	leave
	ret
#endif
