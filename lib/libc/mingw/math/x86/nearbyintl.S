/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"nearbyintl.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
	.globl __MINGW_USYMBOL(nearbyintl)
	.def	__MINGW_USYMBOL(nearbyintl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(nearbyintl):
#if defined(_AMD64_) || defined(__x86_64__)
	fldt	(%rdx)
	movq	%rcx,%r8
	pushq	%rax
	pushq	%rcx
	fnstcw	(%rsp)
	movl	(%rsp), %eax
	orl	$0x20, %eax
	movl	%eax, 8(%rsp)
	fldcw	8(%rsp)
	frndint
	fclex
	fldcw	(%rsp)
	popq	%rcx
	popq	%rax
	movq	%r8,%rax
	movq	$0,8(%r8)
	fstpt	(%r8)
	ret
#elif defined(_X86_) || defined(__i386__)
	fldt	4(%esp)
	pushl	%eax
	pushl	%ecx
	fnstcw	(%esp)
	movl	(%esp), %eax
	orl	$0x20, %eax
	movl	%eax, 4(%esp)
	fldcw	4(%esp)
	frndint
	fclex
	fldcw	(%esp)
	popl	%ecx
	popl	%eax
	ret
#endif
