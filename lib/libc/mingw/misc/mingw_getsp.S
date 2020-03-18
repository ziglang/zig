/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"mingw_getsp.S"
	.text
#ifdef _WIN64
	.align 8
#else
	.align 4
#endif
	.globl __MINGW_USYMBOL(mingw_getsp)
	.def	__MINGW_USYMBOL(mingw_getsp);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(mingw_getsp):
#if defined(_AMD64_) || defined(__x86_64__)
	leaq  8(%rsp),%rax
	ret
#elif defined(_X86_) || defined(__i386__)
	lea	4(%esp),%eax
	ret
#elif defined(_ARM_) || defined(__arm__)
	mov	r0, sp
	bx	lr
#elif defined(_ARM64_) || defined(__aarch64__)
	mov	x0, sp
	ret
#endif
