/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"remquo.S"
        .text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(remquo)
__MINGW_USYMBOL(remquo):
#ifdef __x86_64__
	movsd	%xmm1,-16(%rsp)
	fldl	-16(%rsp)
	movsd	%xmm0,-16(%rsp)
	fldl	-16(%rsp)
1:	fprem1
	fstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	movl %eax, %ecx
	shrl $8, %eax
	shrl $12, %ecx
	andl $4, %ecx
	andl $3, %eax
	orl %eax, %ecx
	leal (%ecx,%ecx,2),%ecx
	movl $0xef2a60, %eax
	shrl %cl, %eax
	andl $7, %eax
	movl -12(%rsp), %edx
	movsd %xmm1,-16(%rsp)
	xorl -12(%rsp), %edx
	testl $0x80000000, %edx
	jz 1f
	negl %eax
1:	movl %eax, (%r8)

	fstpl	-16(%rsp)
	movsd	-16(%rsp),%xmm0
	ret
#else
	fldl 4 +8(%esp)
	fldl 4(%esp)
1:	fprem1
	fstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	movl %eax, %ecx
	shrl $8, %eax
	shrl $12, %ecx
	andl $4, %ecx
	andl $3, %eax
	orl %eax, %ecx
	leal (%ecx,%ecx,2),%ecx
	movl $0xef2a60, %eax
	shrl %cl, %eax
	andl $7, %eax
	movl 4 +8 +8(%esp), %ecx      
	movl 4 +4(%esp), %edx
	xorl 4 +8 +4(%esp), %edx
	testl $0x80000000, %edx
	jz 1f
	negl %eax
1:	movl %eax, (%ecx)

	ret
#endif
