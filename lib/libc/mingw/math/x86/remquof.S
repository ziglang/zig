/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"remquof.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
.globl __MINGW_USYMBOL(remquof)
__MINGW_USYMBOL(remquof):
#ifdef __x86_64__
	movss	%xmm1,-12(%rsp)
	flds -12(%rsp)
	movss	%xmm0,-12(%rsp)
	flds -12(%rsp)
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
	movl $0xef2a60, %eax
	leal (%ecx,%ecx,2),%ecx
	shrl %cl, %eax
	andl $7, %eax
	movss %xmm0,-12(%rsp)
	movl -12(%rsp), %edx
	movss %xmm1,-12(%rsp)
	xorl -12(%rsp), %edx
	testl $0x80000000, %edx
	jz 1f
	negl %eax
1:	movl %eax, (%r8)

	fstps	-12(%rsp)
	movss	-12(%rsp),%xmm0
	ret
#else
	flds 4 +4(%esp)
	flds 4(%esp)
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
	movl $0xef2a60, %eax
	leal (%ecx,%ecx,2),%ecx
	shrl %cl, %eax
	andl $7, %eax
	movl 4 +4 +4(%esp), %ecx
	movl 4(%esp), %edx
	xorl 4 +4(%esp), %edx
	testl $0x80000000, %edx
	jz 1f
	negl %eax
1:	movl %eax, (%ecx)

	ret
#endif
