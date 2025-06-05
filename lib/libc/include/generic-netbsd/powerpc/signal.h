/*	$NetBSD: signal.h,v 1.26 2021/10/29 21:42:02 thorpej Exp $	*/

/*
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_POWERPC_SIGNAL_H_
#define	_POWERPC_SIGNAL_H_

#ifndef _LOCORE
#include <sys/featuretest.h>

/*
 * This is needed natively for 32-bit, and for 32-bit compatibility only
 * in the 64-bit environment.
 */
#if !defined(__LP64__) || defined(_KERNEL)
#define	__HAVE_STRUCT_SIGCONTEXT
#endif

typedef int sig_atomic_t;

#ifndef __LP64__
#if defined(_NETBSD_SOURCE)
#include <sys/sigtypes.h>
#include <machine/frame.h>

#if defined(_KERNEL)
struct sigcontext13 {
	int sc_onstack;			/* saved onstack flag */
	int sc_mask;			/* saved signal mask (old style) */
	struct utrapframe sc_frame;	/* saved registers */
};
#endif /* _KERNEL */

#if defined(_LIBC) || defined(_KERNEL)
/*
 * struct sigcontext introduced in NetBSD 1.4
 */
struct sigcontext {
	int sc_onstack;			/* saved onstack flag */
	int __sc_mask13;		/* saved signal mask (old style) */
	struct utrapframe sc_frame;	/* saved registers */
	sigset_t sc_mask;		/* saved signal mask (new style) */
};
#endif /* _LIBC || _KERNEL */

#endif	/* _NETBSD_SOURCE */
#endif /* __LP64__ */
#endif	/* !_LOCORE */
#endif	/* !_POWERPC_SIGNAL_H_ */