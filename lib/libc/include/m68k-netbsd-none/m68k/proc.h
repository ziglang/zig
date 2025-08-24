/*	$NetBSD: proc.h,v 1.8 2020/12/06 02:26:33 christos Exp $	*/

/*
 * Copyright (c) 1991, 1993
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
 *	@(#)proc.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _M68K_PROC_H
#define _M68K_PROC_H

#include <machine/frame.h>

/*
 * Machine-dependent part of the lwp structure for m68k.
 */
struct mdlwp {
	int	*md_regs;		/* registers on current frame */
	int	md_flags;		/* machine-dependent flags */
};

/* md_flags */
#define MDL_STACKADJ    0x0001  /* frame SP adjusted, might have to
                                   undo when system call returns
                                   ERESTART. */
#define MDL_FPUSED	0x0002	/* floating point coprocessor used (sun[23]) */

struct lwp;

/*
 * Machine-dependent part of the proc structure for m68k-based ports.
 */
struct mdproc {
	int	mdp_flags;		/* machine-dependent flags */
	void	(*md_syscall)(__register_t, struct lwp *, struct frame *);
};

/*
 * Note: The following are the aggregate of all the MDP_* #defines from the
 * various m68k-based ports at the time this file was created.
 * Some of them are probably obsolete and/or not applicable to all ports.
 */
/* md_flags */
#define	MDP_HPUXTRACE	0x0004  /* being traced by HP-UX process */
#define	MDP_HPUXMMAP	0x0008	/* VA space is multiply mapped */
#define MDP_CCBDATA	0x0010	/* copyback caching of data (68040) */
#define MDP_CCBSTACK	0x0020	/* copyback caching of stack (68040) */

#endif /* _M68K_PROC_H */