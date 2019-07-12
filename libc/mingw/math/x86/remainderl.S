/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"remainderl.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(remainderl)
	.def	__MINGW_USYMBOL(remainderl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(remainderl):
#ifdef __x86_64__
	fldt	(%r8)
	fldt	(%rdx)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret
#else
	fldt	16(%esp)
	fldt	4(%esp)
1:	fprem1
	fstsw	%ax
	sahf
	jp	1b
	fstp	%st(1)
	ret
#endif
