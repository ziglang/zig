/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)profile.h	8.1 (Berkeley) 6/11/93
 */

#ifdef __i386__
#include <i386/profile.h>
#else /* !__i386__ */

#ifndef _MACHINE_PROFILE_H_
#define	_MACHINE_PROFILE_H_

#ifndef _KERNEL

#include <sys/cdefs.h>

#define	FUNCTION_ALIGNMENT	4

#define	_MCOUNT_DECL \
static void _mcount(uintfptr_t frompc, uintfptr_t selfpc) __used; \
static void _mcount

#define	MCOUNT __asm("			\n\
	.text				\n\
	.p2align 4,0x90			\n\
	.globl	.mcount			\n\
	.type	.mcount,@function	\n\
.mcount:				\n\
	pushq	%rdi			\n\
	pushq	%rsi			\n\
	pushq	%rdx			\n\
	pushq	%rcx			\n\
	pushq	%r8			\n\
	pushq	%r9			\n\
	pushq	%rax			\n\
	movq	8(%rbp),%rdi		\n\
	movq	7*8(%rsp),%rsi		\n\
	call	_mcount			\n\
	popq	%rax			\n\
	popq	%r9			\n\
	popq	%r8			\n\
	popq	%rcx			\n\
	popq	%rdx			\n\
	popq	%rsi			\n\
	popq	%rdi			\n\
	ret				\n\
	.size	.mcount, . - .mcount");
#if 0
/*
 * We could use this, except it doesn't preserve the registers that were
 * being passed with arguments to the function that we were inserted
 * into.  I've left it here as documentation of what the code above is
 * supposed to do.
 */
#define	MCOUNT								\
void									\
mcount()								\
{									\
	uintfptr_t selfpc, frompc;					\
	/*								\
	 * Find the return address for mcount,				\
	 * and the return address for mcount's caller.			\
	 *								\
	 * selfpc = pc pushed by call to mcount				\
	 */								\
	__asm("movq 8(%%rbp),%0" : "=r" (selfpc));			\
	/*								\
	 * frompc = pc pushed by call to mcount's caller.		\
	 * The caller's stack frame has already been built, so %rbp is	\
	 * the caller's frame pointer.  The caller's raddr is in the	\
	 * caller's frame following the caller's caller's frame pointer.\
	 */								\
	__asm("movq (%%rbp),%0" : "=r" (frompc));			\
	frompc = ((uintfptr_t *)frompc)[1];				\
	_mcount(frompc, selfpc);					\
}
#endif

typedef	u_long	uintfptr_t;

/*
 * An unsigned integral type that can hold non-negative difference between
 * function pointers.
 */
typedef	u_long	fptrdiff_t;

__BEGIN_DECLS
void	mcount(void) __asm(".mcount");
__END_DECLS

#endif /* !_KERNEL */

#endif /* !_MACHINE_PROFILE_H_ */

#endif /* __i386__ */