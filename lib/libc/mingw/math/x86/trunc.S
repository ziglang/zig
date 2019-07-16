/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file "trunc.S"
	.text
	.p2align 4,,15
	.globl __MINGW_USYMBOL(trunc)
        .def    __MINGW_USYMBOL(trunc);  .scl    2;      .type   32;     .endef

#ifdef __x86_64__
	.seh_proc __MINGW_USYMBOL(trunc)
#endif
__MINGW_USYMBOL(trunc):
#if defined(_AMD64_) || defined(__x86_64__)
	subq	$24, %rsp
	.seh_stackalloc	24
	.seh_endprologue
	movsd	%xmm0, 8(%rsp)
	movq	8(%rsp), %r8
	movq	%r8, %rdx
	shrq	$32, %rdx
	movl	%edx, %eax
	sarl	$20, %eax
	andl	$2047, %eax
	leal	-1023(%rax), %ecx
	cmpl	$19, %ecx
	jg	.l1
	movl	%edx, %r8d
	andl	$-2147483648, %r8d
	testl	%ecx, %ecx
	js	.l3
	movl	$1048575, %eax
	sarl	%cl, %eax
	notl	%eax
	andl	%edx, %eax
	orl	%r8d, %eax
	salq	$32, %rax
	movq	%rax, 8(%rsp)
	movsd	8(%rsp), %xmm0
	addq	$24, %rsp
	ret
	.p2align 4,,10
.l1:
	cmpl	$51, %ecx
	jle	.l2
	/* Is x inf/nan? */
	cmpl	$1024, %ecx
	jne	.noinfnan
	addsd	%xmm0, %xmm0
.noinfnan:
	addq	$24, %rsp
	ret
	.p2align 4,,10
.l2:
	leal	-1043(%rax), %ecx
	movl	$-1, %r9d
	salq	$32, %rdx
	shrl	%cl, %r9d
	notl	%r9d
	andl	%r9d, %r8d
	orq	%r8, %rdx
	movq	%rdx, 8(%rsp)
	movsd	8(%rsp), %xmm0
	addq	$24, %rsp
	ret
	.p2align 4,,10
.l3:
	salq	$32, %r8
	movq	%r8, 8(%rsp)
	movsd	8(%rsp), %xmm0
	addq	$24, %rsp
	ret
	.seh_endproc
#elif defined(_X86_) || defined(__i386__)
	fldl    4(%esp)
	subl	$8, %esp
	fstcw	(%esp)
	/* FE_TOWARDZERO */
	movzwl (%esp), %eax
	orb    $0xc, %ah
	movw	%ax, 4(%esp)
	fldcw	4(%esp)
	frndint
	fldcw	(%esp)
	addl	$8, %esp
	ret
#endif
