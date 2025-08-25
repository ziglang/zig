/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"log10l.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
one:	.double 1.0
	/* It is not important that this constant is precise.  It is only
	   a value which is known to be on the safe side for using the
	   fyl2xp1 instruction.  */
limit:	.double 0.29

	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(log10l)
	.def	__MINGW_USYMBOL(log10l);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(log10l):
#ifdef __x86_64__
	fldlg2			// log10(2)
	fldt	(%rdx)		// x : log10(2)
	fxam
	fnstsw
	fld	%st		// x : x : log10(2)
	sahf
	jc	3f		// in case x is NaN or ±Inf
4:	fsubl	one(%rip)	// x-1 : x : log10(2)
	fld	%st		// x-1 : x-1 : x : log10(2)
	fabs			// |x-1| : x-1 : x : log10(2)
	fcompl	limit(%rip)	// x-1 : x : log10(2)
	fnstsw			// x-1 : x : log10(2)
	andb	$0x45, %ah
	jz	2f
	fstp	%st(1)		// x-1 : log10(2)
	fyl2xp1			// log10(x)
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret

2:	fstp	%st(0)		// x : log10(2)
	fyl2x			// log10(x)
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret

3:	jp	4b		// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret
#else
	fldlg2			// log10(2)
	fldt	4(%esp)		// x : log10(2)
	fxam
	fnstsw
	fld	%st		// x : x : log10(2)
	sahf
	jc	3f		// in case x is NaN or ±Inf
4:	fsubl	one		// x-1 : x : log10(2)
	fld	%st		// x-1 : x-1 : x : log10(2)
	fabs			// |x-1| : x-1 : x : log10(2)
	fcompl	limit		// x-1 : x : log10(2)
	fnstsw			// x-1 : x : log10(2)
	andb	$0x45, %ah
	jz	2f
	fstp	%st(1)		// x-1 : log10(2)
	fyl2xp1			// log10(x)
	ret

2:	fstp	%st(0)		// x : log10(2)
	fyl2x			// log10(x)
	ret

3:	jp	4b		// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	ret
#endif
