/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

        .file "truncf.S"
        .text
        .p2align 4,,15
        .globl __MINGW_USYMBOL(truncf)
        .def    __MINGW_USYMBOL(truncf);  .scl    2;      .type   32;     .endef

#ifdef __x86_64__
        .seh_proc __MINGW_USYMBOL(truncf)
#endif
__MINGW_USYMBOL(truncf):
#if defined(_AMD64_) || defined(__x86_64__)
	subq	$24, %rsp
	.seh_stackalloc	24
	.seh_endprologue
	movd	%xmm0, 12(%rsp)
	movl	12(%rsp), %edx
	movl	%edx, %ecx
	sarl	$23, %ecx
	andl	$255, %ecx
	subl	$127, %ecx
	cmpl	$22, %ecx
	jg	.l1
	movl	%edx, %r8d
	andl	$-2147483648, %r8d
	testl	%ecx, %ecx
	js	.l2
	movl	$8388607, %eax
	sarl	%cl, %eax
	notl	%eax
	andl	%edx, %eax
	orl	%r8d, %eax
	movl	%eax, 8(%rsp)
	movss	8(%rsp), %xmm0
	addq	$24, %rsp
	ret
	.p2align 4,,10
.l1:
	addl	$-128, %ecx
	jne	.noinfnan
	addss	%xmm0, %xmm0
.noinfnan:
	addq	$24, %rsp
	ret
	.p2align 4,,10
.l2:
	movl	%r8d, 8(%rsp)
	movss	8(%rsp), %xmm0
	addq	$24, %rsp
	ret
	.seh_endproc
#elif defined(_X86_) || defined(__i386__)
        flds    4(%esp)
        subl    $8, %esp
        fstcw   (%esp)
        /* FE_TOWARDZERO */
        movzwl (%esp), %eax
        orb    $0xc, %ah
        movw    %ax, 4(%esp)
        fldcw   4(%esp)
        frndint
        fldcw   (%esp)
        addl    $8, %esp
        ret
#endif
