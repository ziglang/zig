/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"log1pl.S"
	.text
	/* The fyl2xp1 can only be used for values in
	   -1 + sqrt(2) / 2 <= x <= 1 - sqrt(2) / 2
	   0.29 is a safe value.
	 */

	/* Only gcc understands the .tfloat type
	   The series of .long below represents
	   limit:	.tfloat 0.29
	 */
	.align 16
limit:
	.long 2920577761
	.long 2491081031
	.long 16381
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
	/* Please note:	 we use a double value here.  Since 1.0 has
	   an exact representation this does not effect the accuracy
	   but it helps to optimize the code.  */
one:	.double 1.0

/*
 * Use the fyl2xp1 function when the argument is in the range -0.29 to 0.29,
 * otherwise fyl2x with the needed extra computation.
 */
.globl __MINGW_USYMBOL(log1pl)
	.def	__MINGW_USYMBOL(log1pl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(log1pl):
#ifdef __x86_64__
	fldln2
	fldt	(%rdx)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f		// in case x is NaN or ±Inf
4:
	fabs
	fldt	limit(%rip)
	fcompp
	fnstsw
	sahf
	jnc	2f
	faddl	one(%rip)
	fyl2x
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret

2:	fyl2xp1
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
	fldln2
	fldt	4(%esp)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f		// in case x is NaN or ±Inf
4:
	fabs
	fldt	limit
	fcompp
	fnstsw
	sahf
	jnc	2f
	faddl	one
	fyl2x
	ret

2:	fyl2xp1
	ret

3:	jp	4b		// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	ret
#endif
