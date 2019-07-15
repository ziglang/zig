/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 *
 * IEEE 854 double-extended-precision format
 * unsigned int mantissa1:32
 * unsigned int mantissa0:32
 * unsigned int exponent:15
 * unsigned int negative:1
 * unsigned int empty:16
 *
 * long double _chgsignl(long double x) {
 *   ((unsigned int *) &x)[2] ^= 0x00008000;
 *   return x;
 * }
 */

#include <_mingw_mac.h>

	.file	"_chgignl.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
	.globl __MINGW_USYMBOL(_chgsignl)
	.def	__MINGW_USYMBOL(_chgsignl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(_chgsignl):
#if defined(_AMD64_) || defined(__x86_64__)
	movq	(%rdx), %rax
	movq	8(%rdx), %rdx
	xorq	$0x8000, %rdx
	movq	%rax, (%rcx)
	movq	%rdx, 8(%rcx)
	movq	%rcx, %rax
	ret
#elif defined(_X86_) || defined(__i386__)
	movl	12(%esp),%eax
	xorl	$0x8000,%eax
	movl	%eax,12(%esp)
	fldt	4(%esp)
	ret
#endif

