/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"remainder.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(remainder)
	.def	__MINGW_USYMBOL(remainder);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(remainder):
#ifdef __x86_64__
	movsd	%xmm0,-16(%rsp)
	movsd	%xmm1,-32(%rsp)
	fldl	-32(%rsp)
	fldl	-16(%rsp)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	fstpl	-16(%rsp)
	movsd	-16(%rsp),%xmm0
	ret
#else
	fldl	12(%esp)
	fldl	4(%esp)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	ret
#endif
