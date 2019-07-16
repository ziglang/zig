/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"scalbn.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(scalbn)
	.def	__MINGW_USYMBOL(scalbn);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(scalbn):
#ifdef __x86_64__
	subq	$24, %rsp
	movq	%rdx,(%rsp)
	fildl	(%rsp)
	movsd	%xmm0,(%rsp)
	fldl	(%rsp)
	fscale
	fstp	%st(1)
	fstpl	(%rsp)
	movsd	(%rsp),%xmm0
	addq	$24, %rsp
	ret

#else
	fildl	12(%esp)
	fldl	4(%esp)
	fscale
	fstp	%st(1)
	ret
#endif

.globl __MINGW_USYMBOL(scalbln)
	.set	__MINGW_USYMBOL(scalbln),__MINGW_USYMBOL(scalbn)

