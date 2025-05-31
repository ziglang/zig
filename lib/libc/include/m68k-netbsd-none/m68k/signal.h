/*	$NetBSD: signal.h,v 1.28 2021/10/29 17:29:45 thorpej Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1989, 1991 Regents of the University of California.
 * All rights reserved.
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
 *	@(#)signal.h	7.16 (Berkeley) 3/17/91
 */

#ifndef _M68K_SIGNAL_H_
#define _M68K_SIGNAL_H_

#include <sys/featuretest.h>

#define	__HAVE_STRUCT_SIGCONTEXT

typedef int sig_atomic_t;

#if defined(_NETBSD_SOURCE)

/*
 * Get the "code" values
 */
#include <machine/trap.h>

/*
 * Information pushed on stack when a signal is delivered.
 * This is used by the kernel to restore state following
 * execution of the signal handler.  It is also made available
 * to the handler to allow it to restore state properly if
 * a non-standard exit is performed.
 */
#if defined(_KERNEL)
struct sigcontext13 {
	int	sc_onstack;		/* sigstack state to restore */
	int	sc_mask;		/* signal mask to restore (old style) */
	int	sc_sp;			/* sp to restore */
	int	sc_fp;			/* fp to restore */
	int	sc_ap;			/* ap to restore */
	int	sc_pc;			/* pc to restore */
	int	sc_ps;			/* psl to restore */
};
#endif /* _KERNEL */

#if defined(_LIBC) || defined(_KERNEL)
struct sigcontext {
	int	sc_onstack;		/* sigstack state to restore */
	int	__sc_mask13;		/* signal mask to restore (old style) */
	int	sc_sp;			/* sp to restore */
	int	sc_fp;			/* fp to restore */
	int	sc_ap;			/* ap to restore */
	int	sc_pc;			/* pc to restore */
	int	sc_ps;			/* psl to restore */
	sigset_t sc_mask;		/* signal mask to restore (new style) */
};
#endif /* _LIBC || _KERNEL */

#ifdef _KERNEL
#include <m68k/cpuframe.h>

/*
 * Register state saved while kernel delivers a signal.
 */
struct sigstate {
	int	ss_flags;		/* which of the following are valid */
	struct frame ss_frame;		/* original exception frame */
	struct fpframe ss_fpstate;	/* 68881/68882 state info */
};

#define	SS_RTEFRAME	0x01
#define	SS_FPSTATE	0x02
#define	SS_USERREGS	0x04

u_int fpsr2siginfocode(u_int fpsr);

#endif /* _KERNEL */

#if defined(__M68K_SIGNAL_PRIVATE)

#ifdef _KERNEL
#define	_SIGSTATE_EXFRAMESIZE(fmt)	exframesize[(fmt)]
#endif

#endif /* __M68K_SIGNAL_PRIVATE */

#endif	/* _NETBSD_SOURCE */
#endif	/* !_M68K_SIGNAL_H_ */