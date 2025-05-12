/*	$NetBSD: proc.h,v 1.20 2020/12/06 02:23:12 christos Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)proc.h	8.1 (Berkeley) 6/11/93
 */

#ifndef _SPARC_PROC_H_
#define _SPARC_PROC_H_

/*
 * Machine-dependent parts of the lwp and proc structures for SPARC.
 */
struct mdlwp {
	struct	trapframe *md_tf;	/* trap/syscall registers */
	struct	fpstate *md_fpstate;	/* fpu state, if any; always resident */
	struct cpu_info	*md_fpu;	/* Module holding FPU state */
};

struct mdproc {
	void	(*md_syscall)(__register_t, struct trapframe *, __register_t);
	u_long	md_flags;
};

/* md_flags */
#define	MDP_FIXALIGN	0x1		/* Fix unaligned memory accesses */


#ifdef _KERNEL
/*
 * FPU context switch lock
 * Prevent interrupts that grab the kernel lock
 * XXX mrg: remove (s) argument
 */
extern kmutex_t fpu_mtx;

#define FPU_LOCK(s)		do {	\
	(void)&(s);			\
	mutex_enter(&fpu_mtx);		\
} while (/* CONSTCOND */ 0)

#define FPU_UNLOCK(s)		do {	\
	mutex_exit(&fpu_mtx);		\
} while (/* CONSTCOND */ 0)
#endif

#endif /* _SPARC_PROC_H_ */