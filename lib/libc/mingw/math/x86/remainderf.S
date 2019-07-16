/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"remainderf.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(remainder)
	.def	__MINGW_USYMBOL(remainderf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(remainderf):
#ifdef __x86_64__
	movss	%xmm1,-12(%rsp)
	flds	-12(%rsp)
	movss	%xmm0,-12(%rsp)
	flds	-12(%rsp)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	fstps	-12(%rsp)
	movss	-12(%rsp),%xmm0
	ret
#else
	flds	8(%esp)
	flds	4(%esp)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	ret
#endif
