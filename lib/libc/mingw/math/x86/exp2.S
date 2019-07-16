/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"exp2.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(exp2)
	.def	__MINGW_USYMBOL(exp2);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(exp2):
#ifdef __x86_64__
	subq	$24, %rsp
	movsd	%xmm0,(%rsp)
	fldl	(%rsp)
	fxam				/* Is NaN or +-Inf?  */
	fstsw	%ax
	movb	$0x45, %dh
	andb	%ah, %dh
	cmpb	$0x05, %dh
	je	1f			/* Is +-Inf, jump.  */
	fld	%st
  	subq $8, %rsp /* int(x) */
    	fnstcw 4(%rsp)
    	movzwl 4(%rsp), %eax
    	orb $12, %ah
    	movw %ax, (%rsp)
    	fldcw (%rsp)
    	frndint
    	fldcw 4(%rsp)
    	addq $8, %rsp
	fsubr	%st,%st(1)		/* fract(x) */
	fxch
	f2xm1				/* 2^(fract(x)) - 1 */
	fld1
	faddp				/* 2^(fract(x)) */
	fscale				/* e^x */
	fstp	%st(1)
	fstpl	(%rsp)
	movsd	(%rsp),%xmm0
	addq	$24, %rsp
	ret

1:	testl	$0x200, %eax		/* Test sign.  */
	jz	2f			/* If positive, jump.  */
	fstp	%st
	fldz				/* Set result to 0.  */
2:	fstpl	(%rsp)
	movsd	(%rsp),%xmm0
	addq	$24,%rsp
	ret
#else
	fldl	4(%esp)
/* I added the following ugly construct because exp(+-Inf) resulted
   in NaN.  The ugliness results from the bright minds at Intel.
   For the i686 the code can be written better.
   -- drepper@cygnus.com.  */
	fxam				/* Is NaN or +-Inf?  */
	fstsw	%ax
	movb	$0x45, %dh
	andb	%ah, %dh
	cmpb	$0x05, %dh
	je	1f			/* Is +-Inf, jump.  */
	fld	%st
	subl $8, %esp /* int(x) */
	fnstcw 4(%esp)
	movzwl 4(%esp), %eax
	orb $12, %ah
	movw %ax, (%esp)
	fldcw (%esp)
	frndint
	fldcw 4(%esp)
	addl $8, %esp
	fsubr	%st,%st(1)		/* fract(x) */
	fxch
	f2xm1				/* 2^(fract(x)) - 1 */
	fld1
	faddp				/* 2^(fract(x)) */
	fscale				/* e^x */
	fstp	%st(1)
	ret

1:	testl	$0x200, %eax		/* Test sign.  */
	jz	2f			/* If positive, jump.  */
	fstp	%st
	fldz				/* Set result to 0.  */
2:	ret
#endif
