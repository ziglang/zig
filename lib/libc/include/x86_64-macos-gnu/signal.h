/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*-
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)signal.h	8.3 (Berkeley) 3/30/94
 */

#ifndef _USER_SIGNAL_H
#define _USER_SIGNAL_H

#include <sys/cdefs.h>
#include <_types.h>
#include <sys/signal.h>

#include <sys/_pthread/_pthread_types.h>
#include <sys/_pthread/_pthread_t.h>

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
extern __const char *__const sys_signame[NSIG];
extern __const char *__const sys_siglist[NSIG];
#endif

__BEGIN_DECLS
int	raise(int);
__END_DECLS

#ifndef	_ANSI_SOURCE
__BEGIN_DECLS
void	(* _Nullable bsd_signal(int, void (* _Nullable)(int)))(int);
int	kill(pid_t, int) __DARWIN_ALIAS(kill);
int	killpg(pid_t, int) __DARWIN_ALIAS(killpg);
int	pthread_kill(pthread_t, int);
int	pthread_sigmask(int, const sigset_t *, sigset_t *) __DARWIN_ALIAS(pthread_sigmask);
int	sigaction(int, const struct sigaction * __restrict,
	    struct sigaction * __restrict);
int	sigaddset(sigset_t *, int);
int	sigaltstack(const stack_t * __restrict, stack_t * __restrict)  __DARWIN_ALIAS(sigaltstack) __WATCHOS_PROHIBITED __TVOS_PROHIBITED;
int	sigdelset(sigset_t *, int);
int	sigemptyset(sigset_t *);
int	sigfillset(sigset_t *);
int	sighold(int);
int	sigignore(int);
int	siginterrupt(int, int);
int	sigismember(const sigset_t *, int);
int	sigpause(int) __DARWIN_ALIAS_C(sigpause);
int	sigpending(sigset_t *);
int	sigprocmask(int, const sigset_t * __restrict, sigset_t * __restrict);
int	sigrelse(int);
void    (* _Nullable sigset(int, void (* _Nullable)(int)))(int);
int	sigsuspend(const sigset_t *) __DARWIN_ALIAS_C(sigsuspend);
int	sigwait(const sigset_t * __restrict, int * __restrict) __DARWIN_ALIAS_C(sigwait);
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
void	psignal(unsigned int, const char *);
int	sigblock(int);
int	sigsetmask(int);
int	sigvec(int, struct sigvec *, struct sigvec *);
#endif	/* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
__END_DECLS

/* List definitions after function declarations, or Reiser cpp gets upset. */
#if defined(__i386__) || defined(__x86_64__)
/* The left shift operator on intel is modulo 32 */
__header_always_inline int
__sigbits(int __signo)
{
    return __signo > __DARWIN_NSIG ? 0 : (1 << (__signo - 1));
}
#else /* !__i386__ && !__x86_64__ */
#define __sigbits(signo)	(1 << ((signo) - 1))
#endif /* __i386__ || __x86_64__ */

#define	sigaddset(set, signo)	(*(set) |= __sigbits(signo), 0)
#define	sigdelset(set, signo)	(*(set) &= ~__sigbits(signo), 0)
#define	sigismember(set, signo)	((*(set) & __sigbits(signo)) != 0)
#define	sigemptyset(set)	(*(set) = 0, 0)
#define	sigfillset(set)		(*(set) = ~(sigset_t)0, 0)
#endif	/* !_ANSI_SOURCE */

#endif	/* !_USER_SIGNAL_H */
