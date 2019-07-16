/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"floor.S"
	.text
	.p2align 4,,15
	.globl __MINGW_USYMBOL(floor)
	.def	__MINGW_USYMBOL(floor);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc __MINGW_USYMBOL(floor)
#endif
__MINGW_USYMBOL(floor):
#if defined(_AMD64_) || defined(__x86_64__)
	pushq	%rbx
	.seh_pushreg	%rbx
	subq	$16, %rsp
	.seh_stackalloc	16
	.seh_endprologue
	movsd	%xmm0, 8(%rsp)
	movq	8(%rsp), %r9
	movq	%r9, %rdx
	movl	%r9d, %r10d
	shrq	$32, %rdx
	movl	%edx, %eax
	movl	%edx, %r11d
	sarl	$20, %eax
	andl	$2047, %eax
	leal	-1023(%rax), %r8d
	cmpl	$51, %r8d
	jle	.L2
	cmpl	$1024, %r8d
	je	.L27
.L3:
	addq	$16, %rsp
	popq	%rbx
	ret
	.p2align 4,,10
.L2:
	cmpl	$19, %r8d
	jg	.L4
	testl	%r8d, %r8d
	js	.L28
	movl	$1048575, %eax
	movl	%r8d, %ecx
	shrl	%cl, %eax
	testl	%r9d, %r9d
	jne	.L8
	testl	%edx, %eax
	je	.L3
.L8:
	movsd	.hugeval(%rip), %xmm1
	xorpd	%xmm2, %xmm2
	addsd	%xmm0, %xmm1
	ucomisd	%xmm1, %xmm2
	jae	.L3
	xorl	%r9d, %r9d
	testl	%edx, %edx
	jns	.L9
	movl	$1048576, %r9d
	movl	%r8d, %ecx
	sarl	%cl, %r9d
.L9:
	addl	%r9d, %edx
	notl	%eax
	andl	%edx, %eax
	salq	$32, %rax
	movq	%rax, 8(%rsp)
	movsd	8(%rsp), %xmm0
	addq	$16, %rsp
	popq	%rbx
	ret
	.p2align 4,,10
.L4:
	leal	-1043(%rax), %ecx
	movl	$-1, %ebx
	shrl	%cl, %ebx
	testl	%r9d, %ebx
	je	.L3
	movsd	.hugeval(%rip), %xmm1
	xorpd	%xmm2, %xmm2
	addsd	%xmm0, %xmm1
	ucomisd	%xmm1, %xmm2
	jae	.L3
	testl	%edx, %edx
	js	.L29
.L11:
	notl	%ebx
	salq	$32, %r11
	andl	%ebx, %r10d
	orq	%r10, %r11
	movq	%r11, 8(%rsp)
	movsd	8(%rsp), %xmm0
	addq	$16, %rsp
	popq	%rbx
	ret
	.p2align 4,,10
.L27:
	addsd	%xmm0, %xmm0
	addq	$16, %rsp
	popq	%rbx
	ret
	.p2align 4,,10
.L28:
	movsd	.hugeval(%rip), %xmm2
	xorpd	%xmm1, %xmm1
	addsd	%xmm0, %xmm2
	ucomisd	%xmm1, %xmm2
	jbe	.L3
	testl	%edx, %edx
	js	.L7
	movapd	%xmm1, %xmm0
	jmp	.L3
	.p2align 4,,10
.L7:
	andl	$2147483647, %edx
	orl	%r9d, %edx
	je	.L3
	movabsq	$-4616189618054758400, %rax
	movq	%rax, 8(%rsp)
	movsd	8(%rsp), %xmm0
	jmp	.L3
	.p2align 4,,10
.L29:
	cmpl	$20, %r8d
	je	.L25
	movl	$1075, %ecx
	movl	$1, %r10d
	subl	%eax, %ecx
	sall	%cl, %r10d
	addl	%r9d, %r10d
	jae	.L11
.L25:
	leal	1(%rdx), %r11d
	jmp	.L11
	.seh_endproc

	.section .rdata,"dr"
	.align 8
.hugeval:
	.long	-2013235812
	.long	2117592124
#elif defined(_X86_) || defined(__i386__)
	fldl	4(%esp)
	subl	$8,%esp

	fstcw	4(%esp)			/* store fpu control word */

	/* We use here %edx although only the low 1 bits are defined.
	   But none of the operations should care and they are faster
	   than the 16 bit operations.  */
	movl	$0x400,%edx		/* round towards -oo */
	orl	4(%esp),%edx
	andl	$0xf7ff,%edx
	movl	%edx,(%esp)
	fldcw	(%esp)			/* load modified control word */

	frndint				/* round */

	fldcw	4(%esp)			/* restore original control word */

	addl	$8,%esp
	ret
#endif
