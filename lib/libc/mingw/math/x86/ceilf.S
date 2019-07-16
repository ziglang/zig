/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"ceilf.S"
	.text
	.align 4
	.globl __MINGW_USYMBOL(ceilf)
	.def	__MINGW_USYMBOL(ceilf);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc	__MINGW_USYMBOL(ceilf)
#endif

__MINGW_USYMBOL(ceilf):
#if defined(_AMD64_) || defined(__x86_64__)
        subq    $24, %rsp
        .seh_stackalloc 24
        .seh_endprologue
        movd    %xmm0, 12(%rsp)
        movl    12(%rsp), %eax
        movl    %eax, %ecx
        movl    %eax, %edx
        sarl    $23, %ecx
        andl    $255, %ecx
        subl    $127, %ecx
        cmpl    $22, %ecx
        jg      .l4
        testl   %ecx, %ecx
        js      .l5
        movl    $8388607, %r8d
        sarl    %cl, %r8d
        testl   %eax, %r8d
        je      .l3
        addss   .hugeval(%rip), %xmm0
        ucomiss .zeroval(%rip), %xmm0
        jbe     .l2
        testl   %eax, %eax
        jle     .l1
        movl    $8388608, %eax
        sarl    %cl, %eax
        addl    %eax, %edx
.l1:
        movl    %r8d, %eax
        notl    %eax
        andl    %edx, %eax
.l2:
        movl    %eax, 8(%rsp)
        movss   8(%rsp), %xmm0
.l3:
        addq    $24, %rsp
        ret
        .p2align 4,,10
.l4:
        addl    $-128, %ecx
        jne     .l3
        addss   %xmm0, %xmm0
        addq    $24, %rsp
        ret
        .p2align 4,,10
.l5:
        addss   .hugeval(%rip), %xmm0
        ucomiss .zeroval(%rip), %xmm0
        jbe     .islesseqzero
        testl   %eax, %eax
        js      .l6
        movl    $1065353216, %edx
        cmovne  %edx, %eax
.islesseqzero:
        movl    %eax, 8(%rsp)
        movss   8(%rsp), %xmm0
        addq    $24, %rsp
        ret
        .p2align 4,,10
.l6:
        movl    $-2147483648, 8(%rsp)
        movss   8(%rsp), %xmm0
        addq    $24, %rsp
        ret
        .seh_endproc
        .section .rdata,"dr"
        .align 4
.hugeval:
        .long   1900671690
        .align 4
.zeroval:
        .long   0
#elif defined(_X86_) || defined(__i386__)
	flds	4(%esp)
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
