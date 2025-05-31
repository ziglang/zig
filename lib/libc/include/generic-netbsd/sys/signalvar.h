/*	$NetBSD: signalvar.h,v 1.104 2021/11/01 05:07:17 thorpej Exp $	*/

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
 *	@(#)signalvar.h	8.6 (Berkeley) 2/19/95
 */

#ifndef	_SYS_SIGNALVAR_H_
#define	_SYS_SIGNALVAR_H_

#include <sys/siginfo.h>
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/stdbool.h>

#ifndef _KERNEL
#include <string.h>     /* Required for memset(3) and memcpy(3) prototypes */
#endif /* _KERNEL */

/*
 * Kernel signal definitions and data structures,
 * not exported to user programs.
 */

/*
 * Queue of signals.
 */
typedef TAILQ_HEAD(ksiginfoq, ksiginfo) ksiginfoq_t;

/*
 * Process signal actions, possibly shared between processes.
 */
struct sigacts {
	struct sigact_sigdesc {
		struct sigaction sd_sigact;
		const void	*sd_tramp;
		int		sd_vers;
	} sa_sigdesc[NSIG];		/* disposition of signals */

	int		sa_refcnt;	/* reference count */
	kmutex_t	sa_mutex;	/* lock on sa_refcnt */
};

/*
 * Pending signals, per LWP and per process.
 */
typedef struct sigpend {
	ksiginfoq_t	sp_info;
	sigset_t	sp_set;
} sigpend_t;

/*
 * Process signal state.
 */
struct sigctx {
	struct _ksiginfo ps_info;	/* for core dump/debugger XXX */
	int		 ps_lwp;	/* for core dump/debugger XXX */
	bool		 ps_faked;	/* for core dump/debugger XXX */
	void		*ps_sigcode;	/* address of signal trampoline */
	sigset_t	 ps_sigignore;	/* Signals being ignored. */
	sigset_t	 ps_sigcatch;	/* Signals being caught by user. */
	sigset_t	 ps_sigpass;	/* Signals evading the debugger. */
};

/* additional signal action values, used only temporarily/internally */
#define	SIG_CATCH	(void (*)(int))2

/*
 * get signal action for process and signal; currently only for current process
 */
#define SIGACTION(p, sig)	(p->p_sigacts->sa_sigdesc[(sig)].sd_sigact)
#define	SIGACTION_PS(ps, sig)	(ps->sa_sigdesc[(sig)].sd_sigact)

/*
 * Copy a sigaction structure without padding.
 */
static __inline void
sigaction_copy(struct sigaction *dst, const struct sigaction *src)
{
	memset(dst, 0, sizeof(*dst));
	dst->_sa_u._sa_handler = src->_sa_u._sa_handler;
	memcpy(&dst->sa_mask, &src->sa_mask, sizeof(dst->sa_mask));
	dst->sa_flags = src->sa_flags;
}

/*
 * Signal properties and actions.
 * The array below categorizes the signals and their default actions
 * according to the following properties:
 */
#define	SA_KILL		0x0001		/* terminates process by default */
#define	SA_CORE		0x0002		/* ditto and coredumps */
#define	SA_STOP		0x0004		/* suspend process */
#define	SA_TTYSTOP	0x0008		/* ditto, from tty */
#define	SA_IGNORE	0x0010		/* ignore by default */
#define	SA_CONT		0x0020		/* continue if suspended */
#define	SA_CANTMASK	0x0040		/* non-maskable, catchable */
#define	SA_NORESET	0x0080		/* not reset when caught */
#define	SA_TOLWP	0x0100		/* to LWP that generated, if local */
#define	SA_TOALL	0x0200		/* always to all LWPs */

#ifdef _KERNEL

#include <sys/systm.h>			/* for copyin_t/copyout_t */

extern sigset_t contsigmask, stopsigmask, sigcantmask;

struct vnode;
struct coredump_iostate;

/*
 * Machine-independent functions:
 */
int	coredump_netbsd(struct lwp *, struct coredump_iostate *);
int	coredump_netbsd32(struct lwp *, struct coredump_iostate *);
int	real_coredump_netbsd(struct lwp *, struct coredump_iostate *);
void	execsigs(struct proc *);
int	issignal(struct lwp *);
void	pgsignal(struct pgrp *, int, int);
void	kpgsignal(struct pgrp *, struct ksiginfo *, void *, int);
void	postsig(int);
void	psignal(struct proc *, int);
void	kpsignal(struct proc *, struct ksiginfo *, void *);
void	child_psignal(struct proc *, int);
void	siginit(struct proc *);
void	trapsignal(struct lwp *, struct ksiginfo *);
void	sigexit(struct lwp *, int) __dead;
void	killproc(struct proc *, const char *);
void	setsigvec(struct proc *, int, struct sigaction *);
int	killpg1(struct lwp *, struct ksiginfo *, int, int);
void	proc_unstop(struct proc *p);
void	eventswitch(int, int, int);
void	eventswitchchild(struct proc *, int, int);

int	sigaction1(struct lwp *, int, const struct sigaction *,
	    struct sigaction *, const void *, int);
int	sigprocmask1(struct lwp *, int, const sigset_t *, sigset_t *);
void	sigpending1(struct lwp *, sigset_t *);
void	sigsuspendsetup(struct lwp *, const sigset_t *);
void	sigsuspendteardown(struct lwp *);
int	sigsuspend1(struct lwp *, const sigset_t *);
int	sigaltstack1(struct lwp *, const stack_t *, stack_t *);
int	sigismasked(struct lwp *, int);

int	sigget(sigpend_t *, ksiginfo_t *, int, const sigset_t *);
void	sigclear(sigpend_t *, const sigset_t *, ksiginfoq_t *);
void	sigclearall(struct proc *, const sigset_t *, ksiginfoq_t *);

int	kpsignal2(struct proc *, ksiginfo_t *);

void	signal_init(void);

struct sigacts	*sigactsinit(struct proc *, int);
void	sigactsunshare(struct proc *);
void	sigactsfree(struct sigacts *);

void	kpsendsig(struct lwp *, const struct ksiginfo *, const sigset_t *);
void	sendsig_reset(struct lwp *, int);
void	sendsig(const struct ksiginfo *, const sigset_t *);

ksiginfo_t	*ksiginfo_alloc(struct proc *, ksiginfo_t *, int);
void	ksiginfo_free(ksiginfo_t *);
void	ksiginfo_queue_drain0(ksiginfoq_t *);

struct sys_____sigtimedwait50_args;
int	sigtimedwait1(struct lwp *, const struct sys_____sigtimedwait50_args *,
    register_t *, copyin_t, copyout_t, copyin_t, copyout_t);

void	signotify(struct lwp *);
int	sigispending(struct lwp *, int);

/*
 * Machine-dependent functions:
 */
void	sendsig_sigcontext(const struct ksiginfo *, const sigset_t *);
void	sendsig_siginfo(const struct ksiginfo *, const sigset_t *);

extern	struct pool ksiginfo_pool;

/*
 * firstsig:
 *
 * 	Return the first signal in a signal set.
 */
static __inline int
firstsig(const sigset_t *ss)
{
	int sig;

	sig = ffs(ss->__bits[0]);
	if (sig != 0)
		return (sig);
#if NSIG > 33
	sig = ffs(ss->__bits[1]);
	if (sig != 0)
		return (sig + 32);
#endif
#if NSIG > 65
	sig = ffs(ss->__bits[2]);
	if (sig != 0)
		return (sig + 64);
#endif
#if NSIG > 97
	sig = ffs(ss->__bits[3]);
	if (sig != 0)
		return (sig + 96);
#endif
	return (0);
}

static __inline void
ksiginfo_queue_init(ksiginfoq_t *kq)
{
	TAILQ_INIT(kq);
}

static __inline void
ksiginfo_queue_drain(ksiginfoq_t *kq)
{
	if (!TAILQ_EMPTY(kq))
		ksiginfo_queue_drain0(kq);
}

#endif	/* _KERNEL */

#ifdef	_KERNEL
#ifdef	SIGPROP
const int sigprop[NSIG] = {
	0,					/* 0 unused */
	SA_KILL,				/* 1 SIGHUP */
	SA_KILL,				/* 2 SIGINT */
	SA_KILL|SA_CORE,			/* 3 SIGQUIT */
	SA_KILL|SA_CORE|SA_NORESET|SA_TOLWP,	/* 4 SIGILL */
	SA_KILL|SA_CORE|SA_NORESET|SA_TOLWP,	/* 5 SIGTRAP */
	SA_KILL|SA_CORE,			/* 6 SIGABRT */
	SA_KILL|SA_CORE|SA_TOLWP,		/* 7 SIGEMT */
	SA_KILL|SA_CORE|SA_TOLWP,		/* 8 SIGFPE */
	SA_KILL|SA_CANTMASK|SA_TOALL,		/* 9 SIGKILL */
	SA_KILL|SA_CORE|SA_TOLWP,		/* 10 SIGBUS */
	SA_KILL|SA_CORE|SA_TOLWP,		/* 11 SIGSEGV */
	SA_KILL|SA_CORE|SA_TOLWP,		/* 12 SIGSYS */
	SA_KILL,				/* 13 SIGPIPE */
	SA_KILL,				/* 14 SIGALRM */
	SA_KILL,				/* 15 SIGTERM */
	SA_IGNORE,				/* 16 SIGURG */
	SA_STOP|SA_CANTMASK|SA_TOALL,		/* 17 SIGSTOP */
	SA_STOP|SA_TTYSTOP|SA_TOALL,		/* 18 SIGTSTP */
	SA_IGNORE|SA_CONT|SA_TOALL,		/* 19 SIGCONT */
	SA_IGNORE,				/* 20 SIGCHLD */
	SA_STOP|SA_TTYSTOP|SA_TOALL,		/* 21 SIGTTIN */
	SA_STOP|SA_TTYSTOP|SA_TOALL,		/* 22 SIGTTOU */
	SA_IGNORE,				/* 23 SIGIO */
	SA_KILL,				/* 24 SIGXCPU */
	SA_KILL,				/* 25 SIGXFSZ */
	SA_KILL,				/* 26 SIGVTALRM */
	SA_KILL,				/* 27 SIGPROF */
	SA_IGNORE,				/* 28 SIGWINCH  */
	SA_IGNORE,				/* 29 SIGINFO */
	SA_KILL,				/* 30 SIGUSR1 */
	SA_KILL,				/* 31 SIGUSR2 */
	SA_IGNORE|SA_NORESET,			/* 32 SIGPWR */
	SA_KILL,				/* 33 SIGRTMIN + 0 */
	SA_KILL,				/* 34 SIGRTMIN + 1 */
	SA_KILL,				/* 35 SIGRTMIN + 2 */
	SA_KILL,				/* 36 SIGRTMIN + 3 */
	SA_KILL,				/* 37 SIGRTMIN + 4 */
	SA_KILL,				/* 38 SIGRTMIN + 5 */
	SA_KILL,				/* 39 SIGRTMIN + 6 */
	SA_KILL,				/* 40 SIGRTMIN + 7 */
	SA_KILL,				/* 41 SIGRTMIN + 8 */
	SA_KILL,				/* 42 SIGRTMIN + 9 */
	SA_KILL,				/* 43 SIGRTMIN + 10 */
	SA_KILL,				/* 44 SIGRTMIN + 11 */
	SA_KILL,				/* 45 SIGRTMIN + 12 */
	SA_KILL,				/* 46 SIGRTMIN + 13 */
	SA_KILL,				/* 47 SIGRTMIN + 14 */
	SA_KILL,				/* 48 SIGRTMIN + 15 */
	SA_KILL,				/* 49 SIGRTMIN + 16 */
	SA_KILL,				/* 50 SIGRTMIN + 17 */
	SA_KILL,				/* 51 SIGRTMIN + 18 */
	SA_KILL,				/* 52 SIGRTMIN + 19 */
	SA_KILL,				/* 53 SIGRTMIN + 20 */
	SA_KILL,				/* 54 SIGRTMIN + 21 */
	SA_KILL,				/* 55 SIGRTMIN + 22 */
	SA_KILL,				/* 56 SIGRTMIN + 23 */
	SA_KILL,				/* 57 SIGRTMIN + 24 */
	SA_KILL,				/* 58 SIGRTMIN + 25 */
	SA_KILL,				/* 59 SIGRTMIN + 26 */
	SA_KILL,				/* 60 SIGRTMIN + 27 */
	SA_KILL,				/* 61 SIGRTMIN + 28 */
	SA_KILL,				/* 62 SIGRTMIN + 29 */
	SA_KILL,				/* 63 SIGRTMIN + 30 */
};
#undef	SIGPROP
#else
extern const int sigprop[NSIG];
#endif	/* SIGPROP */
#endif	/* _KERNEL */
#endif	/* !_SYS_SIGNALVAR_H_ */