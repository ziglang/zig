/*
 * Copyright (c) 2000-2006 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
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
 *	@(#)signal.h	8.2 (Berkeley) 1/21/94
 */

#ifndef _SYS_SIGNAL_H_
#define _SYS_SIGNAL_H_

#include <sys/cdefs.h>
#include <sys/appleapiopts.h>
#include <Availability.h>

#define __DARWIN_NSIG   32      /* counting 0; could be 33 (mask is 1-32) */

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define NSIG    __DARWIN_NSIG
#endif

#include <machine/signal.h>     /* sigcontext; codes for SIGILL, SIGFPE */

#define SIGHUP  1       /* hangup */
#define SIGINT  2       /* interrupt */
#define SIGQUIT 3       /* quit */
#define SIGILL  4       /* illegal instruction (not reset when caught) */
#define SIGTRAP 5       /* trace trap (not reset when caught) */
#define SIGABRT 6       /* abort() */
#if  (defined(_POSIX_C_SOURCE) && !defined(_DARWIN_C_SOURCE))
#define SIGPOLL 7       /* pollable event ([XSR] generated, not supported) */
#else   /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define SIGIOT  SIGABRT /* compatibility */
#define SIGEMT  7       /* EMT instruction */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define SIGFPE  8       /* floating point exception */
#define SIGKILL 9       /* kill (cannot be caught or ignored) */
#define SIGBUS  10      /* bus error */
#define SIGSEGV 11      /* segmentation violation */
#define SIGSYS  12      /* bad argument to system call */
#define SIGPIPE 13      /* write on a pipe with no one to read it */
#define SIGALRM 14      /* alarm clock */
#define SIGTERM 15      /* software termination signal from kill */
#define SIGURG  16      /* urgent condition on IO channel */
#define SIGSTOP 17      /* sendable stop signal not from tty */
#define SIGTSTP 18      /* stop signal from tty */
#define SIGCONT 19      /* continue a stopped process */
#define SIGCHLD 20      /* to parent on child stop or exit */
#define SIGTTIN 21      /* to readers pgrp upon background tty read */
#define SIGTTOU 22      /* like TTIN for output if (tp->t_local&LTOSTOP) */
#if  (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define SIGIO   23      /* input/output possible signal */
#endif
#define SIGXCPU 24      /* exceeded CPU time limit */
#define SIGXFSZ 25      /* exceeded file size limit */
#define SIGVTALRM 26    /* virtual time alarm */
#define SIGPROF 27      /* profiling time alarm */
#if  (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define SIGWINCH 28     /* window size changes */
#define SIGINFO 29      /* information request */
#endif
#define SIGUSR1 30      /* user defined signal 1 */
#define SIGUSR2 31      /* user defined signal 2 */

#if defined(_ANSI_SOURCE) || __DARWIN_UNIX03 || defined(__cplusplus)
/*
 * Language spec sez we must list exactly one parameter, even though we
 * actually supply three.  Ugh!
 * SIG_HOLD is chosen to avoid KERN_SIG_* values in <sys/signalvar.h>
 */
#define SIG_DFL         (void (*)(int))0
#define SIG_IGN         (void (*)(int))1
#define SIG_HOLD        (void (*)(int))5
#define SIG_ERR         ((void (*)(int))-1)
#else
/* DO NOT REMOVE THE COMMENTED OUT int: fixincludes needs to see them */
#define SIG_DFL         (void (*)( /*int*/ ))0
#define SIG_IGN         (void (*)( /*int*/ ))1
#define SIG_HOLD        (void (*)( /*int*/ ))5
#define SIG_ERR         ((void (*)( /*int*/ ))-1)
#endif

#ifndef _ANSI_SOURCE
#include <sys/_types.h>

#include <machine/_mcontext.h>

#include <sys/_pthread/_pthread_attr_t.h>

#include <sys/_types/_sigaltstack.h>
#include <sys/_types/_ucontext.h>

#include <sys/_types/_pid_t.h>
#include <sys/_types/_sigset_t.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_uid_t.h>

union sigval {
	/* Members as suggested by Annex C of POSIX 1003.1b. */
	int     sival_int;
	void    *sival_ptr;
};

#define SIGEV_NONE      0       /* No async notification */
#define SIGEV_SIGNAL    1       /* aio - completion notification */
#define SIGEV_THREAD    3       /* [NOTIMP] [RTS] call notification function */

struct sigevent {
	int                             sigev_notify;                           /* Notification type */
	int                             sigev_signo;                            /* Signal number */
	union sigval    sigev_value;                            /* Signal value */
	void                    (*sigev_notify_function)(union sigval);   /* Notification function */
	pthread_attr_t  *sigev_notify_attributes;       /* Notification attributes */
};


typedef struct __siginfo {
	int     si_signo;               /* signal number */
	int     si_errno;               /* errno association */
	int     si_code;                /* signal code */
	pid_t   si_pid;                 /* sending process */
	uid_t   si_uid;                 /* sender's ruid */
	int     si_status;              /* exit value */
	void    *si_addr;               /* faulting instruction */
	union sigval si_value;          /* signal value */
	long    si_band;                /* band event for SIGPOLL */
	unsigned long   __pad[7];       /* Reserved for Future Use */
} siginfo_t;


/*
 * When the signal is SIGILL or SIGFPE, si_addr contains the address of
 * the faulting instruction.
 * When the signal is SIGSEGV or SIGBUS, si_addr contains the address of
 * the faulting memory reference. Although for x86 there are cases of SIGSEGV
 * for which si_addr cannot be determined and is NULL.
 * If the signal is SIGCHLD, the si_pid field will contain the child process ID,
 *  si_status contains the exit value or signal and
 *  si_uid contains the real user ID of the process that sent the signal.
 */

/* Values for si_code */

/* Codes for SIGILL */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define ILL_NOOP        0       /* if only I knew... */
#endif
#define ILL_ILLOPC      1       /* [XSI] illegal opcode */
#define ILL_ILLTRP      2       /* [XSI] illegal trap */
#define ILL_PRVOPC      3       /* [XSI] privileged opcode */
#define ILL_ILLOPN      4       /* [XSI] illegal operand -NOTIMP */
#define ILL_ILLADR      5       /* [XSI] illegal addressing mode -NOTIMP */
#define ILL_PRVREG      6       /* [XSI] privileged register -NOTIMP */
#define ILL_COPROC      7       /* [XSI] coprocessor error -NOTIMP */
#define ILL_BADSTK      8       /* [XSI] internal stack error -NOTIMP */

/* Codes for SIGFPE */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define FPE_NOOP        0       /* if only I knew... */
#endif
#define FPE_FLTDIV      1       /* [XSI] floating point divide by zero */
#define FPE_FLTOVF      2       /* [XSI] floating point overflow */
#define FPE_FLTUND      3       /* [XSI] floating point underflow */
#define FPE_FLTRES      4       /* [XSI] floating point inexact result */
#define FPE_FLTINV      5       /* [XSI] invalid floating point operation */
#define FPE_FLTSUB      6       /* [XSI] subscript out of range -NOTIMP */
#define FPE_INTDIV      7       /* [XSI] integer divide by zero */
#define FPE_INTOVF      8       /* [XSI] integer overflow */

/* Codes for SIGSEGV */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SEGV_NOOP       0       /* if only I knew... */
#endif
#define SEGV_MAPERR     1       /* [XSI] address not mapped to object */
#define SEGV_ACCERR     2       /* [XSI] invalid permission for mapped object */

/* Codes for SIGBUS */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define BUS_NOOP        0       /* if only I knew... */
#endif
#define BUS_ADRALN      1       /* [XSI] Invalid address alignment */
#define BUS_ADRERR      2       /* [XSI] Nonexistent physical address -NOTIMP */
#define BUS_OBJERR      3       /* [XSI] Object-specific HW error - NOTIMP */

/* Codes for SIGTRAP */
#define TRAP_BRKPT      1       /* [XSI] Process breakpoint -NOTIMP */
#define TRAP_TRACE      2       /* [XSI] Process trace trap -NOTIMP */

/* Codes for SIGCHLD */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define CLD_NOOP        0       /* if only I knew... */
#endif
#define CLD_EXITED      1       /* [XSI] child has exited */
#define CLD_KILLED      2       /* [XSI] terminated abnormally, no core file */
#define CLD_DUMPED      3       /* [XSI] terminated abnormally, core file */
#define CLD_TRAPPED     4       /* [XSI] traced child has trapped */
#define CLD_STOPPED     5       /* [XSI] child has stopped */
#define CLD_CONTINUED   6       /* [XSI] stopped child has continued */

/* Codes for SIGPOLL */
#define POLL_IN         1       /* [XSR] Data input available */
#define POLL_OUT        2       /* [XSR] Output buffers available */
#define POLL_MSG        3       /* [XSR] Input message available */
#define POLL_ERR        4       /* [XSR] I/O error */
#define POLL_PRI        5       /* [XSR] High priority input available */
#define POLL_HUP        6       /* [XSR] Device disconnected */

/* union for signal handlers */
union __sigaction_u {
	void    (*__sa_handler)(int);
	void    (*__sa_sigaction)(int, struct __siginfo *,
	    void *);
};

/* Signal vector template for Kernel user boundary */
struct  __sigaction {
	union __sigaction_u __sigaction_u;  /* signal handler */
	void    (*sa_tramp)(void *, int, int, siginfo_t *, void *);
	sigset_t sa_mask;               /* signal mask to apply */
	int     sa_flags;               /* see signal options below */
};

/*
 * Signal vector "template" used in sigaction call.
 */
struct  sigaction {
	union __sigaction_u __sigaction_u;  /* signal handler */
	sigset_t sa_mask;               /* signal mask to apply */
	int     sa_flags;               /* see signal options below */
};



/* if SA_SIGINFO is set, sa_sigaction is to be used instead of sa_handler. */
#define sa_handler      __sigaction_u.__sa_handler
#define sa_sigaction    __sigaction_u.__sa_sigaction

#define SA_ONSTACK      0x0001  /* take signal on signal stack */
#define SA_RESTART      0x0002  /* restart system on signal return */
#define SA_RESETHAND    0x0004  /* reset to SIG_DFL when taking signal */
#define SA_NOCLDSTOP    0x0008  /* do not generate SIGCHLD on child stop */
#define SA_NODEFER      0x0010  /* don't mask the signal we're delivering */
#define SA_NOCLDWAIT    0x0020  /* don't keep zombies around */
#define SA_SIGINFO      0x0040  /* signal handler with SA_SIGINFO args */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SA_USERTRAMP    0x0100  /* do not bounce off kernel's sigtramp */
/* This will provide 64bit register set in a 32bit user address space */
#define SA_64REGSET     0x0200  /* signal handler with SA_SIGINFO args with 64bit regs information */
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/* the following are the only bits we support from user space, the
 * rest are for kernel use only.
 */
#define SA_USERSPACE_MASK (SA_ONSTACK | SA_RESTART | SA_RESETHAND | SA_NOCLDSTOP | SA_NODEFER | SA_NOCLDWAIT | SA_SIGINFO)

/*
 * Flags for sigprocmask:
 */
#define SIG_BLOCK       1       /* block specified signal set */
#define SIG_UNBLOCK     2       /* unblock specified signal set */
#define SIG_SETMASK     3       /* set specified signal set */

/* POSIX 1003.1b required values. */
#define SI_USER         0x10001 /* [CX] signal from kill() */
#define SI_QUEUE        0x10002 /* [CX] signal from sigqueue() */
#define SI_TIMER        0x10003 /* [CX] timer expiration */
#define SI_ASYNCIO      0x10004 /* [CX] aio request completion */
#define SI_MESGQ        0x10005 /* [CX]	from message arrival on empty queue */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
typedef void (*sig_t)(int);     /* type of signal function */
#endif

/*
 * Structure used in sigaltstack call.
 */

#define SS_ONSTACK      0x0001  /* take signal on signal stack */
#define SS_DISABLE      0x0004  /* disable taking signals on alternate stack */
#define MINSIGSTKSZ     32768   /* (32K)minimum allowable stack */
#define SIGSTKSZ        131072  /* (128K)recommended stack size */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * 4.3 compatibility:
 * Signal vector "template" used in sigvec call.
 */
struct  sigvec {
	void    (*sv_handler)(int);     /* signal handler */
	int     sv_mask;                /* signal mask to apply */
	int     sv_flags;               /* see signal options below */
};

#define SV_ONSTACK      SA_ONSTACK
#define SV_INTERRUPT    SA_RESTART      /* same bit, opposite sense */
#define SV_RESETHAND    SA_RESETHAND
#define SV_NODEFER      SA_NODEFER
#define SV_NOCLDSTOP    SA_NOCLDSTOP
#define SV_SIGINFO      SA_SIGINFO

#define sv_onstack sv_flags     /* isn't compatibility wonderful! */
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Structure used in sigstack call.
 */
struct  sigstack {
	char    *ss_sp;                 /* signal stack pointer */
	int     ss_onstack;             /* current status */
};

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Macro for converting signal number to a mask suitable for
 * sigblock().
 */
#define sigmask(m)      (1 << ((m)-1))


#define BADSIG          SIG_ERR

#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif  /* !_ANSI_SOURCE */

/*
 * For historical reasons; programs expect signal's return value to be
 * defined by <sys/signal.h>.
 */
__BEGIN_DECLS
    void(*signal(int, void (*)(int)))(int);
__END_DECLS
#endif  /* !_SYS_SIGNAL_H_ */
