/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"ceill.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
	.globl __MINGW_USYMBOL(ceill)
	.def	__MINGW_USYMBOL(ceill);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(ceill):
#if defined(_AMD64_) || defined(__x86_64__)
	fldt	(%rdx)
	subq	$24,%rsp

	fstcw	8(%rsp)			/* store fpu control word */

	/* We use here %edx although only the low 1 bits are defined.
	   But none of the operations should care and they are faster
	   than the 16 bit operations.  */
	movl	$0x0800,%edx		/* round towards +oo */
	orl	8(%rsp),%edx
	andl	$0xfbff,%edx
	movl	%edx,(%rsp)
	fldcw	(%rsp)			/* load modified control word */

	frndint				/* round */

	fldcw	8(%rsp)			/* restore original control word */

	addq	$24,%rsp
	movq	%rcx,%rax
	movq	$0,8(%rcx)
	fstpt	(%rcx)
	ret
#elif defined(_X86_) || defined(__i386__)
	fldt	4(%esp)
	subl	$8,%esp
	fstcw	4(%esp)
	movl	$0x0800,%edx
	orl	4(%esp),%edx
	andl	$0xfbff,%edx
	movl	%edx,(%esp)
	fldcw	(%esp)
	frndint
	fldcw	4(%esp)
	addl $8,%esp
	ret
#endif
