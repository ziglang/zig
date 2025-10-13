/*	$NetBSD: ptrace.h,v 1.75 2022/06/08 23:12:27 andvar Exp $	*/

/*-
 * Copyright (c) 1984, 1993
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
 *	@(#)ptrace.h	8.2 (Berkeley) 1/4/94
 */

#ifndef	_SYS_PTRACE_H_
#define	_SYS_PTRACE_H_

#include <sys/siginfo.h>
#include <sys/signal.h>

#define	PT_TRACE_ME		0	/* child declares it's being traced */
#define	PT_READ_I		1	/* read word in child's I space */
#define	PT_READ_D		2	/* read word in child's D space */
#define	PT_WRITE_I		4	/* write word in child's I space */
#define	PT_WRITE_D		5	/* write word in child's D space */
#define	PT_CONTINUE		7	/* continue the child */
#define	PT_KILL			8	/* kill the child process */
#define	PT_ATTACH		9	/* attach to running process */
#define	PT_DETACH		10	/* detach from running process */
#define	PT_IO			11	/* do I/O to/from the stopped process */
#define	PT_DUMPCORE		12	/* make child generate a core dump */
#if defined(__LEGACY_PT_LWPINFO) || defined(_KERNEL)
#define	PT_LWPINFO		13	/* OBSOLETE: get info about the LWP */
#endif
#define	PT_SYSCALL		14	/* stop on syscall entry/exit */
#define	PT_SYSCALLEMU		15	/* cancel syscall, tracer emulates it */
#define	PT_SET_EVENT_MASK	16	/* set the event mask, defined below */
#define	PT_GET_EVENT_MASK	17	/* get the event mask, defined below */
#define	PT_GET_PROCESS_STATE	18	/* get process state, defined below */
#define	PT_SET_SIGINFO		19	/* set signal state, defined below */
#define	PT_GET_SIGINFO		20	/* get signal state, defined below */
#define	PT_RESUME		21	/* allow execution of the LWP */
#define	PT_SUSPEND		22	/* prevent execution of the LWP */
#define	PT_STOP			23	/* stop the child process */
#define	PT_LWPSTATUS		24	/* get info about the LWP */
#define	PT_LWPNEXT		25	/* get info about next LWP */
#define	PT_SET_SIGPASS		26	/* set signals to pass to debuggee */
#define	PT_GET_SIGPASS		27	/* get signals to pass to debuggee */

#define	PT_FIRSTMACH		32	/* for machine-specific requests */
#include <machine/ptrace.h>		/* machine-specific requests, if any */

#define PT_STRINGS \
/*  0 */    "PT_TRACE_ME", \
/*  1 */    "PT_READ_I", \
/*  2 */    "PT_READ_D", \
/*  3 */    "*PT_INVALID_3*", \
/*  4 */    "PT_WRITE_I", \
/*  5 */    "PT_WRITE_D", \
/*  6 */    "*PT_INVALID_6*", \
/*  7 */    "PT_CONTINUE", \
/*  8 */    "PT_KILL", \
/*  9 */    "PT_ATTACH", \
/* 10 */    "PT_DETACH", \
/* 11 */    "PT_IO", \
/* 12 */    "PT_DUMPCORE", \
/* 13 */    "PT_LWPINFO", \
/* 14 */    "PT_SYSCALL", \
/* 15 */    "PT_SYSCALLEMU", \
/* 16 */    "PT_SET_EVENT_MASK", \
/* 17 */    "PT_GET_EVENT_MASK", \
/* 18 */    "PT_GET_PROCESS_STATE", \
/* 19 */    "PT_SET_SIGINFO", \
/* 20 */    "PT_GET_SIGINFO", \
/* 21 */    "PT_RESUME", \
/* 22 */    "PT_SUSPEND", \
/* 23 */    "PT_STOP", \
/* 24 */    "PT_LWPSTATUS", \
/* 25 */    "PT_LWPNEXT", \
/* 26 */    "PT_SET_SIGPASS", \
/* 27 */    "PT_GET_SIGPASS"

/* PT_{G,S}EVENT_MASK */
typedef struct ptrace_event {
	int	pe_set_event;
} ptrace_event_t;

/* PT_GET_PROCESS_STATE */
typedef struct ptrace_state {
	int	pe_report_event;
	union {
		pid_t	_pe_other_pid;
		lwpid_t	_pe_lwp;
	} _option;
} ptrace_state_t;

#define	pe_other_pid	_option._pe_other_pid
#define	pe_lwp		_option._pe_lwp

#define	PTRACE_FORK		0x0001	/* Report forks */
#define	PTRACE_VFORK		0x0002	/* Report vforks */
#define	PTRACE_VFORK_DONE	0x0004	/* Report parent resumed from vforks */
#define	PTRACE_LWP_CREATE	0x0008	/* Report LWP creation */
#define	PTRACE_LWP_EXIT		0x0010	/* Report LWP termination */
#define	PTRACE_POSIX_SPAWN	0x0020	/* Report posix_spawn */

/*
 * Argument structure for PT_IO.
 */
struct ptrace_io_desc {
	int	piod_op;	/* I/O operation (see below) */
	void	*piod_offs;	/* child offset */
	void	*piod_addr;	/* parent offset */
	size_t	piod_len;	/* request length (in)/actual count (out) */
};

/* piod_op */
#define	PIOD_READ_D	1	/* read from D space */
#define	PIOD_WRITE_D	2	/* write to D space */
#define	PIOD_READ_I	3	/* read from I space */
#define	PIOD_WRITE_I	4	/* write to I space */
#define PIOD_READ_AUXV	5	/* Read from aux array */

#if defined(__LEGACY_PT_LWPINFO) || defined(_KERNEL)
/*
 * Argument structure for PT_LWPINFO.
 *
 * DEPRECATED: Use ptrace_lwpstatus.
 */
struct ptrace_lwpinfo {
	lwpid_t	pl_lwpid;	/* LWP described */
	int	pl_event;	/* Event that stopped the LWP */
};

#define PL_EVENT_NONE		0
#define PL_EVENT_SIGNAL		1
#define PL_EVENT_SUSPENDED	2
#endif

/*
 * Argument structure for PT_LWPSTATUS.
 */

#define PL_LNAMELEN	20	/* extra 4 for alignment */

struct ptrace_lwpstatus {
	lwpid_t		pl_lwpid;		/* LWP described */
	sigset_t	pl_sigpend;		/* LWP signals pending */
	sigset_t	pl_sigmask;		/* LWP signal mask */
	char		pl_name[PL_LNAMELEN];	/* LWP name, may be empty */
	void		*pl_private;		/* LWP private data */
	/* Add fields at the end */
};

/*
 * Signal Information structure
 */
typedef struct ptrace_siginfo {
	siginfo_t	psi_siginfo;	/* signal information structure */
	lwpid_t		psi_lwpid;	/* destination LWP of the signal
					 * value 0 means the whole process
					 * (route signal to all LWPs) */
} ptrace_siginfo_t;

#ifdef _KERNEL

#ifdef _KERNEL_OPT
#include "opt_compat_netbsd32.h"
#endif

#ifdef COMPAT_NETBSD32
#include <compat/netbsd32/netbsd32.h>
#define process_read_lwpstatus32	netbsd32_read_lwpstatus
#define process_lwpstatus32		struct netbsd32_ptrace_lwpstatus
#endif

#ifndef process_lwpstatus32
#define process_lwpstatus32 struct ptrace_lwpstatus
#endif
#ifndef process_lwpstatus64
#define process_lwpstatus64 struct ptrace_lwpstatus
#endif

#if defined(PT_GETREGS) || defined(PT_SETREGS)
struct reg;
#ifndef process_reg32
#define process_reg32 struct reg
#endif
#ifndef process_reg64
#define process_reg64 struct reg
#endif
#endif

#if defined(PT_GETFPREGS) || defined(PT_SETFPREGS)
struct fpreg;
#ifndef process_fpreg32
#define process_fpreg32 struct fpreg
#endif
#ifndef process_fpreg64
#define process_fpreg64 struct fpreg
#endif
#endif

#if defined(PT_GETDBREGS) || defined(PT_SETDBREGS)
struct dbreg;
#ifndef process_dbreg32
#define process_dbreg32 struct dbreg
#endif
#ifndef process_dbreg64
#define process_dbreg64 struct dbreg
#endif
#endif

struct ptrace_methods {
	int (*ptm_copyin_piod)(struct ptrace_io_desc *, const void *, size_t);
	int (*ptm_copyout_piod)(const struct ptrace_io_desc *, void *, size_t);
	int (*ptm_copyin_siginfo)(struct ptrace_siginfo *, const void *, size_t);
	int (*ptm_copyout_siginfo)(const struct ptrace_siginfo *, void *, size_t);
	int (*ptm_copyout_lwpstatus)(const struct ptrace_lwpstatus *, void *, size_t);
	int (*ptm_doregs)(struct lwp *, struct lwp *, struct uio *);
	int (*ptm_dofpregs)(struct lwp *, struct lwp *, struct uio *);
	int (*ptm_dodbregs)(struct lwp *, struct lwp *, struct uio *);
};

int	ptrace_update_lwp(struct proc *t, struct lwp **lt, lwpid_t lid);
void	ptrace_hooks(void);

int	process_doregs(struct lwp *, struct lwp *, struct uio *);
int	process_validregs(struct lwp *);

int	process_dofpregs(struct lwp *, struct lwp *, struct uio *);
int	process_validfpregs(struct lwp *);

int	process_dodbregs(struct lwp *, struct lwp *, struct uio *);
int	process_validdbregs(struct lwp *);

int	process_domem(struct lwp *, struct lwp *, struct uio *);

void	proc_stoptrace(int, int, const register_t[], const register_t *, int);
void	proc_reparent(struct proc *, struct proc *);
void	proc_changeparent(struct proc *, struct proc *);


int	do_ptrace(struct ptrace_methods *, struct lwp *, int, pid_t, void *,
	    int, register_t *);

void	ptrace_read_lwpstatus(struct lwp *, struct ptrace_lwpstatus *);

void	process_read_lwpstatus(struct lwp *, struct ptrace_lwpstatus *);
#ifndef process_read_lwpstatus32
#define process_read_lwpstatus32 process_read_lwpstatus
#endif
#ifndef process_read_lwpstatus64
#define process_read_lwpstatus64 process_read_lwpstatus
#endif

/*
 * 64bit architectures that support 32bit emulation (amd64 and sparc64)
 * will #define process_read_regs32 to netbsd32_process_read_regs (etc).
 * In all other cases these #defines drop the size suffix.
 */

#ifdef PT_GETDBREGS
int	process_read_dbregs(struct lwp *, struct dbreg *, size_t *);
#ifndef process_read_dbregs32
#define process_read_dbregs32	process_read_dbregs
#endif
#ifndef process_read_dbregs64
#define process_read_dbregs64	process_read_dbregs
#endif
#endif
#ifdef PT_GETFPREGS
int	process_read_fpregs(struct lwp *, struct fpreg *, size_t *);
#ifndef process_read_fpregs32
#define process_read_fpregs32	process_read_fpregs
#endif
#ifndef process_read_fpregs64
#define process_read_fpregs64	process_read_fpregs
#endif
#endif
#ifdef PT_GETREGS
int	process_read_regs(struct lwp *, struct reg *);
#ifndef process_read_regs32
#define process_read_regs32	process_read_regs
#endif
#ifndef process_read_regs64
#define process_read_regs64	process_read_regs
#endif
#endif
int	process_set_pc(struct lwp *, void *);
int	process_sstep(struct lwp *, int);
#ifdef PT_SETDBREGS
int	process_write_dbregs(struct lwp *, const struct dbreg *, size_t);
#ifndef process_write_dbregs32
#define process_write_dbregs32	process_write_dbregs
#endif
#ifndef process_write_dbregs64
#define process_write_dbregs64	process_write_dbregs
#endif
#endif
#ifdef PT_SETFPREGS
int	process_write_fpregs(struct lwp *, const struct fpreg *, size_t);
#ifndef process_write_fpregs32
#define process_write_fpregs32	process_write_fpregs
#endif
#ifndef process_write_fpregs64
#define process_write_fpregs64	process_write_fpregs
#endif
#endif
#ifdef PT_SETREGS
int	process_write_regs(struct lwp *, const struct reg *);
#ifndef process_write_regs32
#define process_write_regs32	process_write_regs
#endif
#ifndef process_write_regs64
#define process_write_regs64	process_write_regs
#endif
#endif

int	ptrace_machdep_dorequest(struct lwp *, struct lwp **, int,
	    void *, int);

#ifndef FIX_SSTEP
#define FIX_SSTEP(p)
#endif

typedef int (*ptrace_regrfunc_t)(struct lwp *, void *, size_t *);
typedef int (*ptrace_regwfunc_t)(struct lwp *, void *, size_t);

#if defined(PT_SETREGS) || defined(PT_GETREGS) || \
    defined(PT_SETFPREGS) || defined(PT_GETFPREGS) || \
    defined(PT_SETDBREGS) || defined(PT_GETDBREGS)
# define PT_REGISTERS
#endif

#else /* !_KERNEL */

#include <sys/cdefs.h>

__BEGIN_DECLS
int	ptrace(int _request, pid_t _pid, void *_addr, int _data);
__END_DECLS

#endif /* !_KERNEL */

#endif	/* !_SYS_PTRACE_H_ */