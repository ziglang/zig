/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
 * Written by J.T. Conklin <jtc@netbsd.org>.
 * Changes for long double by Ulrich Drepper <drepper@cygnus.com>
 * Public domain.
 */
#include <_mingw_mac.h>

	.file	"copysignl.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif

	.globl __MINGW_USYMBOL(copysignl)
	.def	__MINGW_USYMBOL(copysignl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(copysignl):
#if defined(_AMD64_) || defined(__x86_64__)
	movq	(%rdx), %rax
	movq	%rax, (%rcx)
	movq	8(%rdx), %rax
	movq	8(%r8), %rdx
	andq	$0x7fff, %rax
	andq	$0x8000, %rdx
	orq	%rdx, %rax
	movq	%rax, 8(%rcx)
	movq	%rcx, %rax
	ret
#elif defined(_X86_) || defined(__i386__)
	movl	24(%esp),%edx
	movl	12(%esp),%eax
	andl	$0x8000,%edx
	andl	$0x7fff,%eax
	orl	%edx,%eax
	movl	%eax,12(%esp)
	fldt	4(%esp)
	ret
#endif
