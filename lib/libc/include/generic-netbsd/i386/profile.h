/*	$NetBSD: profile.h,v 1.38 2021/11/02 11:26:04 ryo Exp $	*/

/*
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

#ifdef _KERNEL
#include <machine/cpufunc.h>
#endif

#define	_MCOUNT_DECL static __inline void _mcount

#ifdef __ELF__
#define MCOUNT_ENTRY	"__mcount"
#define MCOUNT_COMPAT	__weak_alias(mcount, __mcount)
#else
#define MCOUNT_ENTRY	"mcount"
#define MCOUNT_COMPAT	/* nothing */
#endif

#if defined(_REENTRANT) && !defined(_KERNEL) 
#define MCOUNT_ACTIVE	if (_gmonparam.state != GMON_PROF_ON) return
#else
#define MCOUNT_ACTIVE	
#endif

#define	MCOUNT \
MCOUNT_COMPAT								\
extern void mcount(void) __asm(MCOUNT_ENTRY)				\
	__attribute__((__no_instrument_function__));			\
void									\
mcount(void)								\
{									\
	int selfpc, frompcindex;					\
	int eax, ecx, edx;						\
									\
	MCOUNT_ACTIVE;							\
	__asm volatile("movl %%eax,%0" : "=g" (eax));			\
	__asm volatile("movl %%ecx,%0" : "=g" (ecx));			\
	__asm volatile("movl %%edx,%0" : "=g" (edx));			\
	/*								\
	 * find the return address for mcount,				\
	 * and the return address for mcount's caller.			\
	 *								\
	 * selfpc = pc pushed by mcount call				\
	 */								\
	selfpc = (int)__builtin_return_address(0);			\
	/*								\
	 * frompcindex = stack frame of caller, assuming frame pointer	\
	 */								\
	frompcindex = ((int *)__builtin_frame_address(1))[1];		\
	_mcount((u_long)frompcindex, (u_long)selfpc);			\
									\
	__asm volatile("movl %0,%%edx" : : "g" (edx));			\
	__asm volatile("movl %0,%%ecx" : : "g" (ecx));			\
	__asm volatile("movl %0,%%eax" : : "g" (eax));			\
}

#ifdef _KERNEL
static inline __always_inline void
mcount_disable_intr(void)
{
	__asm volatile("cli");
}

static inline __always_inline u_long
mcount_read_psl(void)
{
	u_long	ef;

	__asm volatile("pushfl; popl %0" : "=r" (ef));
	return (ef);
}

static inline __always_inline void
mcount_write_psl(u_long ef)
{
	__asm volatile("pushl %0; popfl" : : "r" (ef));
}

#define MCOUNT_ENTER	\
	do { s = (int)mcount_read_psl(); mcount_disable_intr(); } while (0)
#define MCOUNT_EXIT	do { mcount_write_psl(s); } while (0)

#endif /* _KERNEL */