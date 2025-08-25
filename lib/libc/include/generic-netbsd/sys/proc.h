/*	$NetBSD: proc.h,v 1.370.4.2 2023/08/09 17:42:01 martin Exp $	*/

/*-
 * Copyright (c) 2006, 2007, 2008, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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

/*-
 * Copyright (c) 1986, 1989, 1991, 1993
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
 *	@(#)proc.h	8.15 (Berkeley) 5/19/95
 */

#ifndef _SYS_PROC_H_
#define	_SYS_PROC_H_

#include <sys/lwp.h>

#if defined(_KMEMUSER) || defined(_KERNEL)

#if defined(_KERNEL_OPT)
#include "opt_multiprocessor.h"
#include "opt_kstack.h"
#include "opt_lockdebug.h"
#endif

#include <machine/proc.h>		/* Machine-dependent proc substruct */
#include <machine/pcb.h>
#include <sys/aio.h>
#include <sys/idtype.h>
#include <sys/rwlock.h>
#include <sys/mqueue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/queue.h>
#include <sys/radixtree.h>
#include <sys/signalvar.h>
#include <sys/siginfo.h>
#include <sys/event.h>
#include <sys/specificdata.h>

#ifdef _KERNEL
#include <sys/resourcevar.h>
#else
#include <sys/time.h>
#include <sys/resource.h>
#endif

/*
 * One structure allocated per session.
 */
struct session {
	int		s_count;	/* Ref cnt; pgrps in session */
	u_int		s_flags;
#define	S_LOGIN_SET	1		/* s_login set in this session */
	struct proc	*s_leader;	/* Session leader */
	struct vnode	*s_ttyvp;	/* Vnode of controlling terminal */
	struct tty	*s_ttyp;	/* Controlling terminal */
	char		s_login[MAXLOGNAME]; /* Setlogin() name */
	pid_t		s_sid;		/* Session ID (pid of leader) */
};

/*
 * One structure allocated per process group.
 */
struct pgrp {
	LIST_HEAD(, proc) pg_members;	/* Pointer to pgrp members */
	struct session	*pg_session;	/* Pointer to session */
	pid_t		pg_id;		/* Pgrp id */
	int		pg_jobc;	/*
					 * Number of processes qualifying
					 * pgrp for job control
					 */
};

/*
 * Autoloadable syscall definition
 */
struct sc_autoload {
	u_int		al_code;
	const char	*al_module;
};

/*
 * One structure allocated per emulation.
 */
struct exec_package;
struct ras;
struct kauth_cred;

struct emul {
	const char	*e_name;	/* Symbolic name */
	const char	*e_path;	/* Extra emulation path (NULL if none)*/
#ifndef __HAVE_MINIMAL_EMUL
	int		e_flags;	/* Miscellaneous flags, see above */
					/* Syscall handling function */
	const int	*e_errno;	/* Errno array */
	int		e_nosys;	/* Offset of the nosys() syscall */
	int		e_nsysent;	/* Number of system call entries */
#endif
	struct sysent	*e_sysent;	/* System call array */
	const uint32_t	*e_nomodbits;	/* sys_nosys/sys_nomodule flags
					 * for syscall_disestablish() */
	const char * const *e_syscallnames; /* System call name array */
	struct sc_autoload *e_sc_autoload; /* List of autoloadable syscalls */
					/* Signal sending function */
	void		(*e_sendsig)(const struct ksiginfo *,
					  const sigset_t *);
	void		(*e_trapsignal)(struct lwp *, struct ksiginfo *);
	char		*e_sigcode;	/* Start of sigcode */
	char		*e_esigcode;	/* End of sigcode */
					/* Set registers before execution */
	struct uvm_object **e_sigobject;/* shared sigcode object */
	void		(*e_setregs)(struct lwp *, struct exec_package *,
					  vaddr_t);

					/* Per-process hooks */
	void		(*e_proc_exec)(struct proc *, struct exec_package *);
	void		(*e_proc_fork)(struct proc *, struct lwp *, int);
	void		(*e_proc_exit)(struct proc *);
	void		(*e_lwp_fork)(struct lwp *, struct lwp *);
	void		(*e_lwp_exit)(struct lwp *);

#ifdef __HAVE_SYSCALL_INTERN
	void		(*e_syscall_intern)(struct proc *);
#else
	void		(*e_syscall)(void);
#endif
					/* Emulation specific sysctl data */
	struct sysctlnode *e_sysctlovly;

	vaddr_t		(*e_vm_default_addr)(struct proc *, vaddr_t, vsize_t,
			     int);

	/* Emulation-specific hook for userspace page faults */
	int		(*e_usertrap)(struct lwp *, vaddr_t, void *);

	size_t		e_ucsize;	/* size of ucontext_t */
	void		(*e_startlwp)(void *);

	/* Dtrace syscall probe */
	void 		(*e_dtrace_syscall)(uint32_t, register_t,
			    const struct sysent *, const void *,
			    const register_t *, int);

	/* Emulation specific support for ktracing signal posts */
	void		(*e_ktrpsig)(int, sig_t, const sigset_t *,
			    const struct ksiginfo *);
};

/*
 * Emulation miscellaneous flags
 */
#define	EMUL_HAS_SYS___syscall	0x001	/* Has SYS___syscall */

/*
 * Description of a process.
 *
 * This structure contains the information needed to manage a thread of
 * control, known in UN*X as a process; it has references to substructures
 * containing descriptions of things that the process uses, but may share
 * with related processes.  The process structure and the substructures
 * are always addressible except for those marked "(PROC ONLY)" below,
 * which might be addressible only on a processor on which the process
 * is running.
 *
 * Field markings and the corresponding locks:
 *
 * a:	p_auxlock
 * k:	ktrace_mutex
 * l:	proc_lock
 * t:	p_stmutex
 * p:	p_lock
 * (:	updated atomically
 * ::	unlocked, stable
 */
struct vmspace;

struct proc {
	LIST_ENTRY(proc) p_list;	/* l: List of all processes */
	kmutex_t	*p_lock;	/* :: general mutex */
	kcondvar_t	p_waitcv;	/* p: wait, stop CV on children */
	kcondvar_t	p_lwpcv;	/* p: wait, stop CV on LWPs */

	/* Substructures: */
	struct kauth_cred *p_cred;	/* p: Master copy of credentials */
	struct filedesc	*p_fd;		/* :: Ptr to open files structure */
	struct cwdinfo	*p_cwdi;	/* :: cdir/rdir/cmask info */
	struct pstats	*p_stats;	/* :: Accounting/stats (PROC ONLY) */
	struct plimit	*p_limit;	/* :: Process limits */
	struct vmspace	*p_vmspace;	/* :: Address space */
	struct sigacts	*p_sigacts;	/* :: Process sigactions */
	struct aioproc	*p_aio;		/* p: Asynchronous I/O data */
	u_int		p_mqueue_cnt;	/* (: Count of open message queues */
	specificdata_reference
			p_specdataref;	/*    subsystem proc-specific data */

	int		p_exitsig;	/* l: signal to send to parent on exit */
	int		p_flag;		/* p: PK_* flags */
	int		p_sflag;	/* p: PS_* flags */
	int		p_slflag;	/* p, l: PSL_* flags */
	int		p_lflag;	/* l: PL_* flags */
	int		p_stflag;	/* t: PST_* flags */
	char		p_stat;		/* p: S* process status. */
	char		p_trace_enabled;/* p: cached by syscall_intern() */
	char		p_pad1[2];	/*  unused */

	pid_t		p_pid;		/* :: Process identifier. */
	LIST_ENTRY(proc) p_pglist;	/* l: List of processes in pgrp. */
	struct proc 	*p_pptr;	/* l: Pointer to parent process. */
	LIST_ENTRY(proc) p_sibling;	/* l: List of sibling processes. */
	LIST_HEAD(, proc) p_children;	/* l: List of children. */
	LIST_HEAD(, lwp) p_lwps;	/* p: List of LWPs. */
	struct ras	*p_raslist;	/* a: List of RAS entries */

/* The following fields are all zeroed upon creation in fork. */
#define	p_startzero	p_nlwps

	int 		p_nlwps;	/* p: Number of LWPs */
	int 		p_nzlwps;	/* p: Number of zombie LWPs */
	int		p_nrlwps;	/* p: Number running/sleeping LWPs */
	int		p_nlwpwait;	/* p: Number of LWPs in lwp_wait1() */
	int		p_ndlwps;	/* p: Number of detached LWPs */
	u_int		p_nstopchild;	/* l: Count of stopped/dead children */
	u_int		p_waited;	/* l: parent has waited on child */
	struct lwp	*p_zomblwp;	/* p: detached LWP to be reaped */
	struct lwp	*p_vforklwp;	/* p: parent LWP waiting at vfork() */

	/* scheduling */
	void		*p_sched_info;	/* p: Scheduler-specific structure */
	fixpt_t		p_estcpu;	/* p: Time avg. value of p_cpticks */
	fixpt_t		p_estcpu_inherited; /* p: cpu inherited from children */
	unsigned int	p_forktime;
	fixpt_t         p_pctcpu;       /* p: %cpu from dead LWPs */

	struct proc	*p_opptr;	/* l: save parent during ptrace. */
	struct ptimers	*p_timers;	/*    Timers: real, virtual, profiling */
	struct bintime 	p_rtime;	/* p: real time */
	u_quad_t 	p_uticks;	/* t: Statclock hits in user mode */
	u_quad_t 	p_sticks;	/* t: Statclock hits in system mode */
	u_quad_t 	p_iticks;	/* t: Statclock hits processing intr */
	uint64_t	p_xutime;	/* p: utime exposed to userspace */
	uint64_t	p_xstime;	/* p: stime exposed to userspace */

	int		p_traceflag;	/* k: Kernel trace points */
	void		*p_tracep;	/* k: Trace private data */
	struct vnode 	*p_textvp;	/* :: Vnode of executable */

	struct emul	*p_emul;	/* :: emulation information */
	void		*p_emuldata;	/* :: per-proc emul data, or NULL */
	const struct execsw *p_execsw;	/* :: exec package information */
	struct klist	p_klist;	/* p: knotes attached to proc */

	LIST_HEAD(, lwp) p_sigwaiters;	/* p: LWPs waiting for signals */
	sigpend_t	p_sigpend;	/* p: pending signals */
	struct lcproc	*p_lwpctl;	/* p, a: _lwp_ctl() information */
	pid_t		p_ppid;		/* :: cached parent pid */
	pid_t		p_oppid;	/* :: cached original parent pid */
	char		*p_path;	/* :: full pathname of executable */

/*
 * End area that is zeroed on creation
 */
#define	p_endzero	p_startcopy

/*
 * The following fields are all copied upon creation in fork.
 */
#define	p_startcopy	p_sigctx

	struct sigctx 	p_sigctx;	/* p: Shared signal state */

	u_char		p_nice;		/* p: Process "nice" value */
	char		p_comm[MAXCOMLEN+1];
					/* p: basename of last exec file */
	struct pgrp 	*p_pgrp;	/* l: Pointer to process group */

	vaddr_t		p_psstrp;	/* :: address of process's ps_strings */
	u_int		p_pax;		/* :: PAX flags */
	int		p_xexit;	/* p: exit code */
/*
 * End area that is copied on creation
 */
#define	p_endcopy	p_xsig
	u_short		p_xsig;		/* p: stop signal */
	u_short		p_acflag;	/* p: Acc. flags; see struct lwp also */
	struct mdproc	p_md;		/* p: Any machine-dependent fields */
	vaddr_t		p_stackbase;	/* :: ASLR randomized stack base */
	struct kdtrace_proc *p_dtrace;	/* :: DTrace-specific data. */
/*
 * Locks in their own cache line towards the end.
 */
	kmutex_t	p_auxlock	/* :: secondary, longer term lock */
	    __aligned(COHERENCY_UNIT);
	kmutex_t	p_stmutex;	/* :: mutex on profiling state */
	krwlock_t	p_reflock;	/* :: lock for debugger, procfs */
};

#define	p_rlimit	p_limit->pl_rlimit
#define	p_session	p_pgrp->pg_session
#define	p_pgid		p_pgrp->pg_id

#endif	/* _KMEMUSER || _KERNEL */

/*
 * Status values.
 */
#define	SIDL		1		/* Process being created by fork */
#define	SACTIVE		2		/* Process is not stopped */
#define	SDYING		3		/* About to die */
#define	SSTOP		4		/* Process debugging or suspension */
#define	SZOMB		5		/* Awaiting collection by parent */
#define	SDEAD	 	6		/* Almost a zombie */

#define	P_ZOMBIE(p)	\
    ((p)->p_stat == SZOMB || (p)->p_stat == SDYING || (p)->p_stat == SDEAD)

/*
 * These flags are kept in p_flag and are protected by p_lock.  Access from
 * process context only.
 */
#define	PK_ADVLOCK	0x00000001 /* Process may hold a POSIX advisory lock */
#define	PK_SYSTEM	0x00000002 /* System process (kthread) */
#define	PK_SYSVSEM	0x00000004 /* Used SysV semaphores */
#define	PK_SUGID	0x00000100 /* Had set id privileges since last exec */
#define	PK_KMEM		0x00000200 /* Has kmem access */
#define	PK_EXEC		0x00004000 /* Process called exec */
#define	PK_NOCLDWAIT	0x00020000 /* No zombies if child dies */
#define	PK_32		0x00040000 /* 32-bit process (used on 64-bit kernels) */
#define	PK_CLDSIGIGN	0x00080000 /* Process is ignoring SIGCHLD */
#define	PK_MARKER	0x80000000 /* Is a dummy marker process */

/*
 * These flags are kept in p_sflag and are protected by p_lock.  Access from
 * process context only.
 */
#define	PS_NOCLDSTOP	0x00000008 /* No SIGCHLD when children stop */
#define	PS_RUMP_LWPEXIT	0x00000400 /* LWPs in RUMP kernel should exit for GC */
#define	PS_WCORE	0x00001000 /* Process needs to dump core */
#define	PS_WEXIT	0x00002000 /* Working on exiting */
#define	PS_STOPFORK	0x00800000 /* Child will be stopped on fork(2) */
#define	PS_STOPEXEC	0x01000000 /* Will be stopped on exec(2) */
#define	PS_STOPEXIT	0x02000000 /* Will be stopped at process exit */
#define	PS_COREDUMP	0x20000000 /* Process core-dumped */
#define	PS_CONTINUED	0x40000000 /* Process is continued */
#define	PS_STOPPING	0x80000000 /* Transitioning SACTIVE -> SSTOP */

/*
 * These flags are kept in p_slflag and are protected by the proc_lock
 * and p_lock.  Access from process context only.
 */
#define	PSL_TRACEFORK	0x00000001 /* traced process wants fork events */
#define	PSL_TRACEVFORK	0x00000002 /* traced process wants vfork events */
#define	PSL_TRACEVFORK_DONE	\
			0x00000004 /* traced process wants vfork done events */
#define	PSL_TRACELWP_CREATE	\
			0x00000008 /* traced process wants LWP create events */
#define	PSL_TRACELWP_EXIT	\
			0x00000010 /* traced process wants LWP exit events */
#define	PSL_TRACEPOSIX_SPAWN	\
			0x00000020 /* traced process wants posix_spawn events */

#define	PSL_TRACED	0x00000800 /* Debugged process being traced */
#define	PSL_TRACEDCHILD 0x00001000 /* Report process birth */
#define	PSL_CHTRACED	0x00400000 /* Child has been traced & reparented */
#define	PSL_SYSCALL	0x04000000 /* process has PT_SYSCALL enabled */
#define	PSL_SYSCALLEMU	0x08000000 /* cancel in-progress syscall */

/*
 * Kept in p_stflag and protected by p_stmutex.
 */
#define	PST_PROFIL	0x00000020 /* Has started profiling */

/*
 * Kept in p_lflag and protected by the proc_lock.  Access
 * from process context only.
 */
#define	PL_CONTROLT	0x00000002 /* Has a controlling terminal */
#define	PL_PPWAIT	0x00000010 /* Parent is waiting for child exec/exit */
#define	PL_SIGCOMPAT	0x00000200 /* Has used compat signal trampoline */
#define	PL_ORPHANPG	0x20000000 /* Member of an orphaned pgrp */

#if defined(_KMEMUSER) || defined(_KERNEL)

/*
 * Macro to compute the exit signal to be delivered.
 */
#define	P_EXITSIG(p)	\
    (((p)->p_slflag & PSL_TRACED) ? SIGCHLD : p->p_exitsig)
/*
 * Compute a wait(2) 16 bit exit status code
 */
#define P_WAITSTATUS(p) W_EXITCODE((p)->p_xexit, ((p)->p_xsig | \
    (((p)->p_sflag & PS_COREDUMP) ? WCOREFLAG : 0)))

LIST_HEAD(proclist, proc);		/* A list of processes */

/*
 * This structure associates a proclist with its lock.
 */
struct proclist_desc {
	struct proclist	*pd_list;	/* The list */
	/*
	 * XXX Add a pointer to the proclist's lock eventually.
	 */
};

#ifdef _KERNEL

/*
 * We use process IDs <= PID_MAX until there are > 16k processes.
 * NO_PGID is used to represent "no process group" for a tty.
 */
#define	PID_MAX		30000
#define	NO_PGID		((pid_t)-1)

#define	SESS_LEADER(p)	((p)->p_session->s_leader == (p))

/*
 * Flags passed to fork1().
 */
#define	FORK_PPWAIT	0x0001		/* Block parent until child exit */
#define	FORK_SHAREVM	0x0002		/* Share vmspace with parent */
#define	FORK_SHARECWD	0x0004		/* Share cdir/rdir/cmask */
#define	FORK_SHAREFILES	0x0008		/* Share file descriptors */
#define	FORK_SHARESIGS	0x0010		/* Share signal actions */
#define	FORK_NOWAIT	0x0020		/* Make init the parent of the child */
#define	FORK_CLEANFILES	0x0040		/* Start with a clean descriptor set */
#define	FORK_SYSTEM	0x0080		/* Fork a kernel thread */

extern struct proc	proc0;		/* Process slot for swapper */
extern u_int		nprocs;		/* Current number of procs */
extern int		maxproc;	/* Max number of procs */
#define	vmspace_kernel()	(proc0.p_vmspace)

extern kmutex_t		proc_lock;
extern struct proclist	allproc;	/* List of all processes */
extern struct proclist	zombproc;	/* List of zombie processes */

extern struct proc	*initproc;	/* Process slots for init, pager */

extern const struct proclist_desc proclists[];

int		proc_find_locked(struct lwp *, struct proc **, pid_t);
proc_t *	proc_find_raw(pid_t);
proc_t *	proc_find(pid_t);		/* Find process by ID */
proc_t *	proc_find_lwpid(pid_t);		/* Find process by LWP ID */
struct lwp *	proc_find_lwp(proc_t *, pid_t);	/* Find LWP in proc by ID */
struct lwp *	proc_find_lwp_unlocked(proc_t *, pid_t);
						/* Find LWP, acquire proc */
struct lwp *	proc_find_lwp_acquire_proc(pid_t, proc_t **);
struct pgrp *	pgrp_find(pid_t);		/* Find process group by ID */

void	procinit(void);
void	procinit_sysctl(void);
int	proc_enterpgrp(struct proc *, pid_t, pid_t, bool);
void	proc_leavepgrp(struct proc *);
void	proc_sesshold(struct session *);
void	proc_sessrele(struct session *);
void	fixjobc(struct proc *, struct pgrp *, int);

int	tsleep(wchan_t, pri_t, const char *, int);
int	mtsleep(wchan_t, pri_t, const char *, int, kmutex_t *);
void	wakeup(wchan_t);
int	kpause(const char *, bool, int, kmutex_t *);
void	exit1(struct lwp *, int, int) __dead;
int	kill1(struct lwp *l, pid_t pid, ksiginfo_t *ksi, register_t *retval);
int	do_sys_wait(int *, int *, int, struct rusage *);
int	do_sys_waitid(idtype_t, id_t, int *, int *, int, struct wrusage *,
	    siginfo_t *);

struct proc *proc_alloc(void);
void	proc0_init(void);
pid_t	proc_alloc_pid(struct proc *);
void	proc_free_pid(pid_t);
pid_t	proc_alloc_lwpid(struct proc *, struct lwp *);
void	proc_free_lwpid(struct proc *, pid_t);
void	proc_free_mem(struct proc *);
void	exit_lwps(struct lwp *l);
int	fork1(struct lwp *, int, int, void *, size_t,
	    void (*)(void *), void *, register_t *);
int	pgid_in_session(struct proc *, pid_t);
void	cpu_lwp_fork(struct lwp *, struct lwp *, void *, size_t,
	    void (*)(void *), void *);
void	cpu_lwp_free(struct lwp *, int);
void	cpu_lwp_free2(struct lwp *);
void	cpu_spawn_return(struct lwp*);

#ifdef __HAVE_SYSCALL_INTERN
void	syscall_intern(struct proc *);
#endif

void	md_child_return(struct lwp *);
void	child_return(void *);

int	proc_isunder(struct proc *, struct lwp *);
int	proc_uidmatch(kauth_cred_t, kauth_cred_t);

int	proc_vmspace_getref(struct proc *, struct vmspace **);
void	proc_crmod_leave(kauth_cred_t, kauth_cred_t, bool);
void	proc_crmod_enter(void);
int	proc_getauxv(struct proc *, void **, size_t *);

int	proc_specific_key_create(specificdata_key_t *, specificdata_dtor_t);
void	proc_specific_key_delete(specificdata_key_t);
void	proc_initspecific(struct proc *);
void	proc_finispecific(struct proc *);
void *	proc_getspecific(struct proc *, specificdata_key_t);
void	proc_setspecific(struct proc *, specificdata_key_t, void *);
int	proc_compare(const struct proc *, const struct lwp *,
    const struct proc *, const struct lwp *);

/*
 * Special handlers for delivering EVFILT_PROC notifications.  These
 * exist to handle some of the special locking considerations around
 * processes.
 */
void	knote_proc_exec(struct proc *);
void	knote_proc_fork(struct proc *, struct proc *);
void	knote_proc_exit(struct proc *);

int	proclist_foreach_call(struct proclist *,
    int (*)(struct proc *, void *arg), void *);

static __inline struct proc *
_proclist_skipmarker(struct proc *p0)
{
	struct proc *p = p0;

	while (p != NULL && p->p_flag & PK_MARKER)
		p = LIST_NEXT(p, p_list);

	return p;
}

#define PROC_PTRSZ(p) (((p)->p_flag & PK_32) ? sizeof(int) : sizeof(void *))
#define PROC_REGSZ(p) (((p)->p_flag & PK_32) ? \
    sizeof(process_reg32) : sizeof(struct reg))
#define PROC_FPREGSZ(p) (((p)->p_flag & PK_32) ? \
    sizeof(process_fpreg32) : sizeof(struct fpreg))
#define PROC_DBREGSZ(p) (((p)->p_flag & PK_32) ? \
    sizeof(process_dbreg32) : sizeof(struct dbreg))

#ifndef PROC_MACHINE_ARCH
#define PROC_MACHINE_ARCH(p) machine_arch
#endif

/*
 * PROCLIST_FOREACH: iterate on the given proclist, skipping PK_MARKER ones.
 */
#define	PROCLIST_FOREACH(var, head)					\
	for ((var) = LIST_FIRST(head);					\
		((var) = _proclist_skipmarker(var)) != NULL;		\
		(var) = LIST_NEXT(var, p_list))

#ifdef KSTACK_CHECK_MAGIC
void	kstack_setup_magic(const struct lwp *);
void	kstack_check_magic(const struct lwp *);
#else
#define	kstack_setup_magic(x)
#define	kstack_check_magic(x)
#endif

extern struct emul emul_netbsd;

#endif	/* _KERNEL */

/*
 * Kernel stack parameters.
 *
 * KSTACK_LOWEST_ADDR: return the lowest address of the LWP's kernel stack,
 * excluding red-zone.
 *
 * KSTACK_SIZE: the size kernel stack for a LWP, excluding red-zone.
 *
 * if <machine/proc.h> provides the MD definition, it will be used.
 */
#ifndef KSTACK_LOWEST_ADDR
#define	KSTACK_LOWEST_ADDR(l)	((void *)ALIGN((struct pcb *)((l)->l_addr) + 1))
#endif
#ifndef KSTACK_SIZE
#define	KSTACK_SIZE		(USPACE - ALIGN(sizeof(struct pcb)))
#endif

#endif	/* _KMEMUSER || _KERNEL */

#endif	/* !_SYS_PROC_H_ */