/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"ceil.S"
	.text
	.align 4
	.globl __MINGW_USYMBOL(ceil)
	.def	__MINGW_USYMBOL(ceil);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc	__MINGW_USYMBOL(ceil)
#endif

__MINGW_USYMBOL(ceil):
#if defined(_AMD64_) || defined(__x86_64__)
	.seh_endprologue
	movd %xmm0, %rax
	movq	%rax, %rcx
	sarq	$52, %rcx
	andl	$2047, %ecx
	subl	$1023, %ecx
	cmpl	$51, %ecx
	jg	.is_intnaninf
	/* Is x zero? */
	testq	%rax, %rax
	je	.ret_org
	/* Is x signed? */
	testl	%ecx, %ecx
	js	.signed_val
	/* Is x integral? */
	movabsq	$4503599627370495, %rdx
	sarq	%cl, %rdx
	testq	%rax, %rdx
	je	.ret_org
	addsd	.huge(%rip), %xmm0
	ucomisd	.zero(%rip), %xmm0
	jbe	.doret
	testq	%rax, %rax
	jle	.l1
	/* inexact ... */
	movabsq	$4503599627370496, %r8
	shrq	%cl, %r8
	addq	%r8, %rax
.l1:
	notq	%rdx
	andq	%rdx, %rax
.doret:
	movd %rax, %xmm0
	ret
	.p2align 4,,10
.signed_val:
	addsd	.huge(%rip), %xmm0
	ucomisd	.zero(%rip), %xmm0
	jbe	.doret2
	testq	%rax, %rax
	movabsq	$4607182418800017408, %rdx
	movabsq	$-9223372036854775808, %rax
	cmovns	%rdx, %rax
	.p2align 4,,10
.doret2:
	movd %rax, %xmm0
	ret

	.p2align 4,,10
.is_intnaninf:
	/* Is Nan or Inf? */
	cmpl	$1024, %ecx
	je	.ret_naninf
	.p2align 4,,10
.ret_org:
	/* return x.  */
	rep
	ret
	.p2align 4,,10
.ret_naninf:
	/* return x + x; */
	addsd	%xmm0, %xmm0
	ret
	.seh_endproc

/* local data.  */
	.section .rdata,"dr"
	.align 8
.huge:
	.long	-2013235812
	.long	2117592124
	.align 8
.zero:
	.long	0
	.long	0
#elif defined(_X86_) || defined(__i386__)
	fldl	4(%esp)
	subl	$8,%esp

	fstcw	4(%esp)			/* store fpu control word */

	/* We use here %edx although only the low 1 bits are defined.
	   But none of the operations should care and they are faster
	   than the 16 bit operations.  */
	movl	$0x0800,%edx		/* round towards +oo */
	orl	4(%esp),%edx
	andl	$0xfbff,%edx
	movl	%edx,(%esp)
	fldcw	(%esp)			/* load modified control word */

	frndint				/* round */

	fldcw	4(%esp)			/* restore original control word */

	addl	$8,%esp
	ret
#endif
