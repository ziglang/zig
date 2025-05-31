/*	$NetBSD: signal.h,v 1.75.4.2 2024/10/14 17:44:57 martin Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1989, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)signal.h	8.4 (Berkeley) 5/4/95
 */

#ifndef	_SYS_SIGNAL_H_
#define	_SYS_SIGNAL_H_

#include <sys/featuretest.h>
#include <sys/sigtypes.h>

#define _NSIG		64

#if defined(_NETBSD_SOURCE)
#define NSIG _NSIG

#endif /* _NETBSD_SOURCE */

#define	SIGHUP		1	/* hangup */
#define	SIGINT		2	/* interrupt */
#define	SIGQUIT		3	/* quit */
#define	SIGILL		4	/* illegal instruction (not reset when caught) */
#define	SIGTRAP		5	/* trace trap (not reset when caught) */
#define	SIGABRT		6	/* abort() */
#define	SIGIOT		SIGABRT	/* compatibility */
#define	SIGEMT		7	/* EMT instruction */
#define	SIGFPE		8	/* floating point exception */
#define	SIGKILL		9	/* kill (cannot be caught or ignored) */
#define	SIGBUS		10	/* bus error */
#define	SIGSEGV		11	/* segmentation violation */
#define	SIGSYS		12	/* bad argument to system call */
#define	SIGPIPE		13	/* write on a pipe with no one to read it */
#define	SIGALRM		14	/* alarm clock */
#define	SIGTERM		15	/* software termination signal from kill */
#define	SIGURG		16	/* urgent condition on IO channel */
#define	SIGSTOP		17	/* sendable stop signal not from tty */
#define	SIGTSTP		18	/* stop signal from tty */
#define	SIGCONT		19	/* continue a stopped process */
#define	SIGCHLD		20	/* to parent on child stop or exit */
#define	SIGTTIN		21	/* to readers pgrp upon background tty read */
#define	SIGTTOU		22	/* like TTIN for output if (tp->t_local&LTOSTOP) */
#define	SIGIO		23	/* input/output possible signal */
#define	SIGXCPU		24	/* exceeded CPU time limit */
#define	SIGXFSZ		25	/* exceeded file size limit */
#define	SIGVTALRM	26	/* virtual time alarm */
#define	SIGPROF		27	/* profiling time alarm */
#define	SIGWINCH	28	/* window size changes */
#define	SIGINFO		29	/* information request */
#define	SIGUSR1		30	/* user defined signal 1 */
#define	SIGUSR2		31	/* user defined signal 2 */
#define	SIGPWR		32	/* power fail/restart (not reset when caught) */
#define	SIGRTMIN	33
#define	SIGRTMAX	63

#ifndef _KERNEL
#include <sys/cdefs.h>
#endif

#define	SIG_DFL		((void (*)(int))  0)
#define	SIG_IGN		((void (*)(int))  1)
#define	SIG_ERR		((void (*)(int)) -1)
#define	SIG_HOLD	((void (*)(int))  3)

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)

#ifdef _KERNEL
#define	sigaddset(s, n)		__sigaddset(s, n)
#define	sigdelset(s, n)		__sigdelset(s, n)
#define	sigismember(s, n)	__sigismember(s, n)
#define	sigemptyset(s)		__sigemptyset(s)
#define	sigfillset(s)		__sigfillset(s)
#define sigplusset(s, t)	__sigplusset(s, t)
#define sigminusset(s, t)	__sigminusset(s, t)
#endif /* _KERNEL */

#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#include <sys/siginfo.h>
#endif

#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
#include <sys/ucontext.h>
#endif /* _XOPEN_SOURCE_EXTENDED || _XOPEN_SOURCE >= 500 || _NETBSD_SOURCE */

/*
 * Signal vector "template" used in sigaction call.
 */
struct	sigaction {
	union {
		void (*_sa_handler)(int);
#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
		void (*_sa_sigaction)(int, siginfo_t *, void *);
#endif
	} _sa_u;	/* signal handler */
	sigset_t sa_mask;		/* signal mask to apply */
	int	sa_flags;		/* see signal options below */
};

#define sa_handler _sa_u._sa_handler
#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#define sa_sigaction _sa_u._sa_sigaction
#endif

/*
 * Signal return trampoline versioning:
 *
 * In historical BSD, the kernel provided the signal trampoline, copying
 * it out to the process's stack.  In NetBSD 2.0, the signal trampoline
 * was moved into libc, and versioned in order to support the historical
 * BSD "sigcontext" style of handler in addition to the modern "siginfo"
 * style of handler.  The trampoline and its ABI version are registered
 * with the kernel along with the handlers.
 *
 * The versioning follows this general pattern:
 *
 * 0	Historical BSD style, trampoline provided by the kernel.  This is
 * 	now used only by COMPAT_* modules.
 *
 * 1	Legacy BSD "sigcontext" trampoline.  This style is deprecated and
 *	no longer documented.  However, on platforms that have a legacy
 *	"sigcontext" structure, it is still possible to register a handler
 *	that uses this trampoline.
 *
 * 2	Modern "siginfo" trampoline.  This style is used if a handler
 *	explicitly requests "siginfo", or if the deprecation of "sigcontext"
 *	style handlers pre-dates support for the platform.
 *
 * Some architectures have, in the past, needed to version the "sigcontext"
 * trampoline; an override mechanism is provided for this purpose.  No more
 * changes to the old "sigcontext" trampoline ABI will ever be performed,
 * and support for it should not be included when adding support for new
 * architectures.  Those architectures that support the "sigcontext"
 * trampoline must define __HAVE_STRUCT_SIGCONTEXT in <machine/signal.h>.
 * If a 64-bit architecture needs to support "sigcontext" trampolines only
 * for 32-bit compatibility, then __HAVE_STRUCT_SIGCONTEXT can be conditional
 * on _KERNEL.
 *
 * If an architecture defines a sigcontext structure in <machine/signal.h>,
 * it should be visible only for _KERNEL and _LIBC.
 *
 * In the unlikely event that an an architecture needs to version
 * the "siginfo" trampoline, it can achieve this by overriding the
 * various __SIGTRAMP_SIGINFO_VERSION-related constants.
 */

#include <machine/signal.h>	/* sigcontext; codes for SIGILL, SIGFPE */

#define	__SIGTRAMP_SIGCODE_VERSION	  0

#define	__SIGTRAMP_SIGCONTEXT_VERSION_MIN 1

#ifndef __SIGTRAMP_SIGCONTEXT_VERSION_MAX
#define	__SIGTRAMP_SIGCONTEXT_VERSION_MAX 1
#endif

#ifndef __SIGTRAMP_SIGCONTEXT_VERSION
#define	__SIGTRAMP_SIGCONTEXT_VERSION     1
#endif

#if __SIGTRAMP_SIGCONTEXT_VERSION_MAX < __SIGTRAMP_SIGCONTEXT_VERSION_MIN
#error invalid __SIGTRAMP_SIGCONTEXT_VERSION_MAX
#endif

#ifndef __SIGTRAMP_SIGINFO_VERSION_MIN
#define	__SIGTRAMP_SIGINFO_VERSION_MIN    2
#endif

#ifndef __SIGTRAMP_SIGINFO_VERSION_MAX
#define	__SIGTRAMP_SIGINFO_VERSION_MAX    2
#endif

#ifndef __SIGTRAMP_SIGINFO_VERSION
#define	__SIGTRAMP_SIGINFO_VERSION        2
#endif

#if __SIGTRAMP_SIGINFO_VERSION_MAX < __SIGTRAMP_SIGINFO_VERSION_MIN
#error invalid __SIGTRAMP_SIGINFO_VERSION_MAX
#endif

#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || (_POSIX_C_SOURCE - 0) >= 200809L || \
    defined(_NETBSD_SOURCE)
#define SA_ONSTACK	0x0001	/* take signal on signal stack */
#define SA_RESTART	0x0002	/* restart system call on signal return */
#define SA_RESETHAND	0x0004	/* reset to SIG_DFL when taking signal */
#define SA_NODEFER	0x0010	/* don't mask the signal we're delivering */
#endif /* _XOPEN_SOURCE_EXTENDED || _XOPEN_SOURCE >= 500 || _POSIX_C_SOURCE >= 200809L || _NETBSD_SOURCE */
/* Only valid for SIGCHLD. */
#define SA_NOCLDSTOP	0x0008	/* do not generate SIGCHLD on child stop */
#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#define SA_NOCLDWAIT	0x0020	/* do not generate zombies on unwaited child */
#define SA_SIGINFO	0x0040	/* take sa_sigaction handler */
#endif /* (_POSIX_C_SOURCE - 0) >= 199309L || ... */
#if defined(_NETBSD_SOURCE)
#define	SA_NOKERNINFO	0x0080	/* siginfo does not print kernel info on tty */
#endif /*_NETBSD_SOURCE */
#ifdef _KERNEL
#define	SA_ALLBITS	0x00ff
#endif

/*
 * Flags for sigprocmask():
 */
#define	SIG_BLOCK	1	/* block specified signal set */
#define	SIG_UNBLOCK	2	/* unblock specified signal set */
#define	SIG_SETMASK	3	/* set specified signal set */

#if defined(_NETBSD_SOURCE)
typedef	void (*sig_t)(int);	/* type of signal function */

#define SS_INIT 		/* Initializer for stack_t */ \
    ((stack_t) { .ss_sp = NULL, .ss_flags = SS_DISABLE,  .ss_size = 0 })

#endif

#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || (_POSIX_C_SOURCE - 0) >= 200809L || \
    defined(_NETBSD_SOURCE)
/*
 * Flags used with stack_t/struct sigaltstack.
 */
#define SS_ONSTACK	0x0001	/* take signals on alternate stack */
#define SS_DISABLE	0x0004	/* disable taking signals on alternate stack */
#ifdef _KERNEL
#define	SS_ALLBITS	0x0005
#endif
#define	MINSIGSTKSZ	8192			/* minimum allowable stack */
#define	SIGSTKSZ	(MINSIGSTKSZ + 32768)	/* recommended stack size */
#endif /* _XOPEN_SOURCE_EXTENDED || _XOPEN_SOURCE >= 500
	* || _POSIX_C_SOURCE >= 200809L || _NETBSD_SOURCE
	*/

#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || (_POSIX_C_SOURCE - 0) >= 200809L || \
    defined(_NETBSD_SOURCE)
/*
 * Structure used in sigstack call.
 */
struct	sigstack {
	void	*ss_sp;			/* signal stack pointer */
	int	ss_onstack;		/* current status */
};
#endif /* _XOPEN_SOURCE_EXTENDED || _XOPEN_SOURCE >= 500
	* || _POSIX_C_SOURCE >= 200809L || _NETBSD_SOURCE
	*/

#if defined(_NETBSD_SOURCE) && !defined(_KERNEL)
/*
 * Macro for converting signal number to a mask suitable for
 * sigblock().
 */
#define sigmask(n)	__sigmask(n)

#define	BADSIG		SIG_ERR
#endif /* _NETBSD_SOURCE */

#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
struct	sigevent {
	int	sigev_notify;
	int	sigev_signo;
	union sigval	sigev_value;
	void	(*sigev_notify_function)(union sigval);
	void /* pthread_attr_t */	*sigev_notify_attributes;
};

#define SIGEV_NONE	0
#define SIGEV_SIGNAL	1
#define SIGEV_THREAD	2
#if defined(_NETBSD_SOURCE)
#define SIGEV_SA	3
#endif
#endif /* (_POSIX_C_SOURCE - 0) >= 199309L || ... */

#endif	/* _POSIX_C_SOURCE || _XOPEN_SOURCE || _NETBSD_SOURCE */

/*
 * For historical reasons; programs expect signal's return value to be
 * defined by <sys/signal.h>.
 */
__BEGIN_DECLS
void	(*signal(int, void (*)(int)))(int);
#if (_POSIX_C_SOURCE - 0) >= 200112L || defined(_NETBSD_SOURCE)
int	sigqueue(pid_t, int, const union sigval);
#endif

#if defined(_NETBSD_SOURCE) ||					\
    (!defined (_XOPEN_SOURCE) && defined(_XOPEN_VERSION) &&	\
	(_XOPEN_VERSION - 0) >= 4) ||				\
    (defined(_XOPEN_SOURCE) && (_XOPEN_SOURCE - 0) <= 600)
/*
 * bsd_signal() was added to the standards in POSIX issue 4 (SusV4)
 * (release 2 of SusV4) and then removed in POSIX issue 7 (2008),
 * after being marked obsolete in POSIX issue 6 (2001).  It was
 * always an X/Open extension function (though was moved to the
 * base POSIX spec in issue 5, but still as an extension).
 */
void	(*bsd_signal(int, void (*)(int)))(int);
#endif
#if defined(_NETBSD_SOURCE)
int	sigqueueinfo(pid_t, const siginfo_t *);
#endif
__END_DECLS
#endif	/* !_SYS_SIGNAL_H_ */