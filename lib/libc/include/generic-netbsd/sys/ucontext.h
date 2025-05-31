/*	$NetBSD: ucontext.h,v 1.19 2018/02/27 23:09:02 uwe Exp $	*/

/*-
 * Copyright (c) 1999, 2003 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein, and by Jason R. Thorpe.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_UCONTEXT_H_
#define _SYS_UCONTEXT_H_

#include <sys/sigtypes.h>
#include <machine/mcontext.h>

typedef struct __ucontext	ucontext_t;

struct __ucontext {
	unsigned int	uc_flags;	/* properties */
	ucontext_t * 	uc_link;	/* context to resume */
	sigset_t	uc_sigmask;	/* signals blocked in this context */
	stack_t		uc_stack;	/* the stack used by this context */
	mcontext_t	uc_mcontext;	/* machine state */
#if defined(_UC_MACHINE_PAD)
	long		__uc_pad[_UC_MACHINE_PAD];
#endif
};

#ifndef _UC_UCONTEXT_ALIGN
#define _UC_UCONTEXT_ALIGN (~0)
#endif

/* uc_flags */
#define _UC_SIGMASK	0x01		/* valid uc_sigmask */
#define _UC_STACK	0x02		/* valid uc_stack */
#define _UC_CPU		0x04		/* valid GPR context in uc_mcontext */
#define _UC_FPU		0x08		/* valid FPU context in uc_mcontext */
#define	_UC_MD		0x400f0020	/* MD bits.  see below */

/*
 * if your port needs more MD bits, please try to choose bits from _UC_MD
 * first, rather than picking random unused bits.
 *
 * _UC_MD details
 *
 * 	_UC_TLSBASE	Context contains valid pthread private pointer 
 *			All ports must define this MD flag
 * 			0x00040000	hppa, mips
 * 			0x00000020	alpha
 *			0x00080000	all other ports
 *
 *	_UC_SETSTACK	Context uses signal stack
 *			0x00020000	arm
 *			[undefined]	alpha, powerpc and vax
 *			0x00010000	other ports
 *
 *	_UC_CLRSTACK	Context does not use signal stack
 *			0x00040000	arm
 *			[undefined]	alpha, powerpc and vax
 *			0x00020000	other ports
 *
 *	_UC_POWERPC_VEC Context contains valid AltiVec context
 *			0x00010000	powerpc only
 *
 *	_UC_POWERPC_SPE	Context contains valid SPE context
 *			0x00020000	powerpc only
 *
 *	_UC_M68K_UC_USER Used by m68k machdep code, but undocumented
 *			0x40000000	m68k only
 *
 *	_UC_ARM_VFP	Unused
 *			0x00010000	arm only
 *
 *	_UC_VM		Context contains valid virtual 8086 context
 *			0x00040000	i386, amd64 only
 *
 *	_UC_FXSAVE	Context contains FPU context in that 
 *			is in FXSAVE format in XMM space 
 *			0x00000020	i386, amd64 only
 */

#ifdef _KERNEL
struct lwp;

void	getucontext(struct lwp *, ucontext_t *);
int	setucontext(struct lwp *, const ucontext_t *);
void	cpu_getmcontext(struct lwp *, mcontext_t *, unsigned int *);
int	cpu_setmcontext(struct lwp *, const mcontext_t *, unsigned int);
int	cpu_mcontext_validate(struct lwp *, const mcontext_t *);

#ifdef __UCONTEXT_SIZE
__CTASSERT(sizeof(ucontext_t) == __UCONTEXT_SIZE);
#endif
#endif /* _KERNEL */

#endif /* !_SYS_UCONTEXT_H_ */