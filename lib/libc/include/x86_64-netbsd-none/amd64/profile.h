/*	$NetBSD: profile.h,v 1.21 2021/11/02 11:26:03 ryo Exp $	*/

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

#ifdef __x86_64__

#ifdef _KERNEL_OPT
#include "opt_xen.h"
#endif

#define	_MCOUNT_DECL void _mcount

#define EPROL_EXPORT	__asm(".globl _eprol")

#ifdef __PIC__
#define __MCPLT	"@PLT"
#else
#define __MCPLT
#endif

#define	MCOUNT						\
__weak_alias(mcount, __mcount)				\
__asm(" .globl __mcount		\n"			\
"	.type __mcount,@function\n"			\
"__mcount:			\n"			\
"	pushq	%rbp		\n"			\
"	movq	%rsp,%rbp	\n"			\
"	subq	$56,%rsp	\n"			\
"	movq	%rdi,0(%rsp)	\n"			\
"	movq	%rsi,8(%rsp)	\n"			\
"	movq	%rdx,16(%rsp)	\n"			\
"	movq	%rcx,24(%rsp)	\n"			\
"	movq	%r8,32(%rsp)	\n"			\
"	movq	%r9,40(%rsp)	\n"			\
"	movq	%rax,48(%rsp)	\n"			\
"	movq	0(%rbp),%r11	\n"			\
"	movq	8(%r11),%rdi	\n"			\
"	movq	8(%rbp),%rsi	\n"			\
"	call	_mcount"__MCPLT "	\n"			\
"	movq	0(%rsp),%rdi	\n"			\
"	movq	8(%rsp),%rsi	\n"			\
"	movq	16(%rsp),%rdx	\n"			\
"	movq	24(%rsp),%rcx	\n"			\
"	movq	32(%rsp),%r8	\n"			\
"	movq	40(%rsp),%r9	\n"			\
"	movq	48(%rsp),%rax	\n"			\
"	leave			\n"			\
"	ret			\n"			\
"	.size __mcount,.-__mcount");


#ifdef _KERNEL
#ifdef XENPV
static inline __always_inline void
mcount_disable_intr(void)
{
	/* should be __cli() but this calls x86_lfence() which calls mcount */
	curcpu()->ci_vcpu->evtchn_upcall_mask = 1;
	__asm volatile("lfence" ::: "memory"); /* x86_lfence() */
}

static inline __always_inline u_long
mcount_read_psl(void)
{
	return (curcpu()->ci_vcpu->evtchn_upcall_mask);
}

static inline __always_inline void
mcount_write_psl(u_long psl)
{
	curcpu()->ci_vcpu->evtchn_upcall_mask = psl;
	/* can't call x86_lfence because it calls mcount() */
	__asm volatile("lfence" ::: "memory"); /* x86_lfence() */
	/* XXX can't call hypervisor_force_callback() because we're in mcount*/
}

#else /* XENPV */
static inline __always_inline void
mcount_disable_intr(void)
{
	__asm volatile("cli");
}

static inline __always_inline u_long
mcount_read_psl(void)
{
	u_long	ef;

	__asm volatile("pushfq; popq %0" : "=r" (ef));
	return (ef);
}

static inline __always_inline void
mcount_write_psl(u_long ef)
{
	__asm volatile("pushq %0; popfq" : : "r" (ef));
}

#endif /* XENPV */

#define MCOUNT_ENTER	\
	do { s = (int)mcount_read_psl(); mcount_disable_intr(); } while (0)
#define MCOUNT_EXIT	do { mcount_write_psl(s); } while (0)

#endif /* _KERNEL */

#else	/*	__x86_64__	*/

#include <i386/profile.h>

#endif	/*	__x86_64__	*/