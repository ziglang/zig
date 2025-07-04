/*	$NetBSD: lwp.h,v 1.217 2022/07/23 19:15:29 mrg Exp $	*/

/*
 * Copyright (c) 2001, 2006, 2007, 2008, 2009, 2010, 2019, 2020
 *    The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Nathan J. Williams and Andrew Doran.
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

#ifndef _SYS_LWP_H_
#define _SYS_LWP_H_

#if defined(_KERNEL) || defined(_KMEMUSER)

#include <sys/param.h>
#include <sys/time.h>
#include <sys/queue.h>
#include <sys/callout.h>
#include <sys/kcpuset.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/signalvar.h>
#include <sys/sched.h>
#include <sys/specificdata.h>
#include <sys/syncobj.h>
#include <sys/resource.h>

#if defined(_KERNEL)
struct lwp;
/* forward declare this for <machine/cpu.h> so it can get l_cpu. */
static __inline struct cpu_info *lwp_getcpu(struct lwp *);
#include <machine/cpu.h>		/* curcpu() and cpu_info */
#include <sys/atomic.h>
#ifdef _KERNEL_OPT
#include "opt_kcov.h"
#include "opt_kmsan.h"
#include "opt_maxlwp.h"
#endif
#endif

#include <machine/proc.h>		/* Machine-dependent proc substruct. */

/*
 * Lightweight process.  Field markings and the corresponding locks:
 *
 * a:	proc_lock
 * c:	condition variable interlock, passed to cv_wait()
 * l:	*l_mutex
 * p:	l_proc->p_lock
 * s:	spc_mutex, which may or may not be referenced by l_mutex
 * S:	l_selcluster->sc_lock
 * (:	unlocked, stable
 * !:	unlocked, may only be reliably accessed by the LWP itself
 *
 * Fields are clustered together by usage (to increase the likelihood
 * of cache hits) and by size (to reduce dead space in the structure).
 */

#include <sys/pcu.h>

struct lockdebug;
struct sysent;

struct lwp {
	/* Must not be zeroed on free. */
	struct cpu_info *volatile l_cpu;/* s: CPU we're on if LSONPROC */
	kmutex_t * volatile l_mutex;	/* l: ptr to mutex on sched state */
	struct turnstile *l_ts;		/* l: current turnstile */
	int		l_stat;		/* l: overall LWP status */
	int		l__reserved;	/*  : padding - reuse as needed */

	/* Scheduling and overall state. */
#define	l_startzero l_runq
	TAILQ_ENTRY(lwp) l_runq;	/* s: run queue */
	union {
		void *	info;		/* s: scheduler-specific structure */
		u_int	timeslice;	/* l: time-quantum for SCHED_M2 */
	} l_sched;
	void		*l_addr;	/* l: PCB address; use lwp_getpcb() */
	struct mdlwp	l_md;		/* l: machine-dependent fields. */
	struct bintime 	l_rtime;	/* l: real time */
	struct bintime	l_stime;	/* l: start time (while ONPROC) */
	int		l_flag;		/* l: misc flag values */
	u_int		l_swtime;	/* l: time swapped in or out */
	u_int		l_rticks;	/* l: Saved start time of run */
	u_int		l_rticksum;	/* l: Sum of ticks spent running */
	u_int		l_slpticks;	/* l: Saved start time of sleep */
	u_int		l_slpticksum;	/* l: Sum of ticks spent sleeping */
	int		l_biglocks;	/* l: biglock count before sleep */
	int		l_class;	/* l: scheduling class */
	int		l_kpriority;	/* !: has kernel priority boost */
	pri_t		l_kpribase;	/* !: kernel priority base level */
	pri_t		l_priority;	/* l: scheduler priority */
	pri_t		l_inheritedprio;/* l: inherited priority */
	pri_t		l_protectprio;	/* l: for PTHREAD_PRIO_PROTECT */
	pri_t		l_auxprio;	/* l: max(inherit,protect) priority */
	int		l_protectdepth;	/* l: for PTHREAD_PRIO_PROTECT */
	u_int		l_cpticks;	/* (: Ticks of CPU time */
	psetid_t	l_psid;		/* l: assigned processor-set ID */
	fixpt_t		l_pctcpu;	/* p: %cpu during l_swtime */
	fixpt_t		l_estcpu;	/* l: cpu time for SCHED_4BSD */
	volatile uint64_t l_ncsw;	/* l: total context switches */
	volatile uint64_t l_nivcsw;	/* l: involuntary context switches */
	SLIST_HEAD(, turnstile) l_pi_lenders; /* l: ts lending us priority */
	struct cpu_info *l_target_cpu;	/* l: target CPU to migrate */
	struct lwpctl	*l_lwpctl;	/* p: lwpctl block kernel address */
	struct lcpage	*l_lcpage;	/* p: lwpctl containing page */
	kcpuset_t	*l_affinity;	/* l: CPU set for affinity */

	/* Synchronisation. */
	struct syncobj	*l_syncobj;	/* l: sync object operations set */
	LIST_ENTRY(lwp) l_sleepchain;	/* l: sleep queue */
	wchan_t		l_wchan;	/* l: sleep address */
	const char	*l_wmesg;	/* l: reason for sleep */
	struct sleepq	*l_sleepq;	/* l: current sleep queue */
	callout_t	l_timeout_ch;	/* !: callout for tsleep */
	kcondvar_t	l_waitcv;	/* a: vfork() wait */
	u_int		l_slptime;	/* l: time since last blocked */
	bool		l_vforkwaiting;	/* a: vfork() waiting */

	/* User-space synchronization. */
	uintptr_t	l_robust_head;	/* !: list of robust futexes */
	uint32_t	l___rsvd1;	/* reserved for future use */

#if PCU_UNIT_COUNT > 0
	struct cpu_info	* volatile l_pcu_cpu[PCU_UNIT_COUNT];
	uint32_t	l_pcu_valid;
#endif

	/* Process level and global state, misc. */
	lwpid_t		l_lid;		/* (: LWP identifier; local to proc */
	LIST_ENTRY(lwp)	l_list;		/* a: entry on list of all LWPs */
	void		*l_ctxlink;	/* p: uc_link {get,set}context */
	struct proc	*l_proc;	/* p: parent process */
	LIST_ENTRY(lwp)	l_sibling;	/* p: entry on proc's list of LWPs */
	char		*l_name;	/* (: name, optional */
	lwpid_t		l_waiter;	/* p: first LWP waiting on us */
	lwpid_t 	l_waitingfor;	/* p: specific LWP we are waiting on */
	int		l_prflag;	/* p: process level flags */
	u_int		l_refcnt;	/* p: reference count on this LWP */

	/* State of select() or poll(). */
	int		l_selflag;	/* S: polling state flags */
	int		l_selret;	/* S: return value of select/poll */
	SLIST_HEAD(,selinfo) l_selwait;	/* S: descriptors waited on */
	uintptr_t	l_selrec;	/* !: argument for selrecord() */
	struct selcluster *l_selcluster;/* !: associated cluster data */
	void *		l_selbits;	/* (: select() bit-field */
	size_t		l_selni;	/* (: size of a single bit-field */

	/* Signals. */
	int		l_sigrestore;	/* p: need to restore old sig mask */
	sigset_t	l_sigwaitset;	/* p: signals being waited for */
	kcondvar_t	l_sigcv;	/* p: for sigsuspend() */
	struct ksiginfo	*l_sigwaited;	/* p: delivered signals from set */
	sigpend_t	*l_sigpendset;	/* p: XXX issignal()/postsig() baton */
	LIST_ENTRY(lwp)	l_sigwaiter;	/* p: chain on list of waiting LWPs */
	stack_t		l_sigstk;	/* p: sp & on stack state variable */
	sigset_t	l_sigmask;	/* p: signal mask */
	sigpend_t	l_sigpend;	/* p: signals to this LWP */
	sigset_t	l_sigoldmask;	/* p: mask for sigpause */

	/* Private data. */
	specificdata_reference
		l_specdataref;		/* !: subsystem lwp-specific data */
	struct timespec l_ktrcsw;	/* !: for ktrace CSW trace XXX */
	void		*l_private;	/* !: svr4-style lwp-private data */
	struct lwp	*l_switchto;	/* !: mi_switch: switch to this LWP */
	struct kauth_cred *l_cred;	/* !: cached credentials */
	struct filedesc	*l_fd;		/* !: cached copy of proc::p_fd */
	void		*l_emuldata;	/* !: kernel lwp-private data */
	struct fstrans_lwp_info *l_fstrans; /* (: fstrans private data */
	u_short		l_shlocks;	/* !: lockdebug: shared locks held */
	u_short		l_exlocks;	/* !: lockdebug: excl. locks held */
	u_short		l_psrefs;	/* !: count of psref held */
	u_short		l_blcnt;	/* !: count of kernel_lock held */
	volatile int	l_nopreempt;	/* !: don't preempt me! */
	volatile u_int	l_dopreempt;	/* s: kernel preemption pending */
	int		l_pflag;	/* !: LWP private flags */
	int		l_dupfd;	/* !: side return from cloning devs XXX */
	const struct sysent * volatile l_sysent;/* !: currently active syscall */
	struct rusage	l_ru;		/* !: accounting information */
	uint64_t	l_pfailtime;	/* !: for kernel preemption */
	uintptr_t	l_pfailaddr;	/* !: for kernel preemption */
	uintptr_t	l_pfaillock;	/* !: for kernel preemption */
	_TAILQ_HEAD(,struct lockdebug,volatile) l_ld_locks;/* !: locks held by LWP */
	volatile void	*l_ld_wanted;	/* !: lock currently wanted by LWP */
	uintptr_t	l_rwcallsite;	/* !: rwlock actual callsite */
	int		l_tcgen;	/* !: for timecounter removal */

	/* These are only used by 'options SYSCALL_TIMES'. */
	uint32_t	l_syscall_time;	/* !: time epoch for current syscall */
	uint64_t	*l_syscall_counter; /* !: counter for current process */

	struct kdtrace_thread *l_dtrace; /* (: DTrace-specific data. */

#ifdef KMSAN
	void		*l_kmsan; /* !: KMSAN private data. */
#endif
#ifdef KCOV
	void		*l_kcov; /* !: KCOV private data. */
#endif
};

/*
 * UAREA_PCB_OFFSET: an offset of PCB structure in the uarea.  MD code may
 * define it in <machine/proc.h>, to indicate a different uarea layout.
 */
#ifndef UAREA_PCB_OFFSET
#define	UAREA_PCB_OFFSET	0
#endif

LIST_HEAD(lwplist, lwp);		/* A list of LWPs. */

#ifdef _KERNEL
extern struct lwplist	alllwp;		/* List of all LWPs. */
extern lwp_t		lwp0;		/* LWP for proc0. */
extern int		maxlwp __read_mostly;	/* max number of lwps */
#ifndef MAXLWP
#define	MAXLWP		4096		/* default max */
#endif
#ifndef MAXMAXLWP
#define MAXMAXLWP	65535		/* absolute max */
#endif
#endif

#endif /* _KERNEL || _KMEMUSER */

/*
 * These flags are kept in l_flag, and they are modified only with the LWP
 * locked.
 */
#define	LW_IDLE		0x00000001 /* Idle lwp. */
#define	LW_LWPCTL	0x00000002 /* Adjust lwpctl in userret */
#define	LW_STIMO	0x00000040 /* Sleep timed out */
#define	LW_SINTR	0x00000080 /* Sleep is interruptible. */
#define	LW_CATCHINTR	0x00000100 /* LW_SINTR intent; see sleepq_block(). */
#define	LW_SYSTEM	0x00000200 /* Kernel thread */
#define	LW_SYSTEM_FPU	0x00000400 /* Kernel thread with vector/FP enabled */
#define	LW_DBGSUSPEND	0x00010000 /* Suspend by debugger */
#define	LW_WSUSPEND	0x00020000 /* Suspend before return to user */
#define	LW_BATCH	0x00040000 /* LWP tends to hog CPU */
#define	LW_WCORE	0x00080000 /* Stop for core dump on return to user */
#define	LW_WEXIT	0x00100000 /* Exit before return to user */
#define	LW_PENDSIG	0x01000000 /* Pending signal for us */
#define	LW_CANCELLED	0x02000000 /* tsleep should not sleep */
#define	LW_WREBOOT	0x08000000 /* System is rebooting, please suspend */
#define	LW_UNPARKED	0x10000000 /* Unpark op pending */
#define	LW_RUMP_CLEAR	0x40000000 /* Clear curlwp in RUMP scheduler */
#define	LW_RUMP_QEXIT	0x80000000 /* LWP should exit ASAP */

/*
 * The second set of flags is kept in l_pflag, and they are modified only by
 * the LWP itself, or modified when it's known the LWP cannot be running.
 * LP_RUNNING is typically updated with the LWP locked, but not always in
 * the case of soft interrupt handlers.
 */
#define	LP_KTRACTIVE	0x00000001 /* Executing ktrace operation */
#define	LP_KTRCSW	0x00000002 /* ktrace context switch marker */
#define	LP_KTRCSWUSER	0x00000004 /* ktrace context switch marker */
	/* 		0x00000008    was LP_PIDLID */
#define	LP_OWEUPC	0x00000010 /* Owe user profiling tick */
#define	LP_MPSAFE	0x00000020 /* Starts life without kernel_lock */
#define	LP_INTR		0x00000040 /* Soft interrupt handler */
#define	LP_SYSCTLWRITE	0x00000080 /* sysctl write lock held */
#define	LP_MUSTJOIN	0x00000100 /* Must join kthread on exit */
#define	LP_SINGLESTEP	0x00000400 /* Single step thread in ptrace(2) */
#define	LP_TIMEINTR	0x00010000 /* Time this soft interrupt */
#define	LP_PREEMPTING	0x00020000 /* mi_switch called involuntarily */
#define	LP_RUNNING	0x20000000 /* Active on a CPU */
#define	LP_TELEPORT	0x40000000 /* Teleport to new CPU on preempt() */
#define	LP_BOUND	0x80000000 /* Bound to a CPU */

/*
 * The third set of flags is kept in l_prflag and they are modified only
 * with p_lock held.
 */
#define	LPR_DETACHED	0x00800000 /* Won't be waited for. */
#define	LPR_CRMOD	0x00000100 /* Credentials modified */
#define	LPR_DRAINING	0x80000000 /* Draining references before exiting */

/*
 * Mask indicating that there is "exceptional" work to be done on return to
 * user.
 */
#define	LW_USERRET	\
    (LW_WEXIT | LW_PENDSIG | LW_WREBOOT | LW_WSUSPEND | LW_WCORE | LW_LWPCTL)

/*
 * Status values.
 *
 * A note about LSRUN and LSONPROC: LSRUN indicates that a process is
 * runnable but *not* yet running, i.e. is on a run queue.  LSONPROC
 * indicates that the process is actually executing on a CPU, i.e.
 * it is no longer on a run queue.
 *
 * These values are set in stone and must not be reused with future changes.
 */
#define	LSIDL		1	/* Process being created by fork. */
#define	LSRUN		2	/* Currently runnable. */
#define	LSSLEEP		3	/* Sleeping on an address. */
#define	LSSTOP		4	/* Process debugging or suspension. */
#define	LSZOMB		5	/* Awaiting collection by parent. */
/* define	LSDEAD	6	Process is almost a zombie. (removed in 5.0) */
#define	LSONPROC	7	/* Process is currently on a CPU. */
#define	LSSUSPENDED	8	/* Not running, not signalable. */

#if defined(_KERNEL) || defined(_KMEMUSER)
static __inline void *
lwp_getpcb(struct lwp *l)
{

	return l->l_addr;
}
#endif /* _KERNEL || _KMEMUSER */

#ifdef _KERNEL
#define	LWP_CACHE_CREDS(l, p)						\
do {									\
	(void)p;							\
	if (__predict_false((l)->l_prflag & LPR_CRMOD))			\
		lwp_update_creds(l);					\
} while (/* CONSTCOND */ 0)

void	lwpinit(void);
void	lwp0_init(void);

void	lwp_startup(lwp_t *, lwp_t *);
void	startlwp(void *);

int	lwp_locked(lwp_t *, kmutex_t *);
kmutex_t *lwp_setlock(lwp_t *, kmutex_t *);
void	lwp_unlock_to(lwp_t *, kmutex_t *);
int	lwp_trylock(lwp_t *);
void	lwp_addref(lwp_t *);
void	lwp_delref(lwp_t *);
void	lwp_delref2(lwp_t *);
bool	lwp_drainrefs(lwp_t *);
bool	lwp_alive(lwp_t *);
lwp_t	*lwp_find_first(proc_t *);

int	lwp_wait(lwp_t *, lwpid_t, lwpid_t *, bool);
void	lwp_continue(lwp_t *);
void	lwp_unsleep(lwp_t *, bool);
void	lwp_unstop(lwp_t *);
void	lwp_exit(lwp_t *);
int	lwp_suspend(lwp_t *, lwp_t *);
int	lwp_create1(lwp_t *, const void *, size_t, u_long, lwpid_t *);
void	lwp_start(lwp_t *, int);
void	lwp_update_creds(lwp_t *);
void	lwp_migrate(lwp_t *, struct cpu_info *);
lwp_t *	lwp_find2(pid_t, lwpid_t);
lwp_t *	lwp_find(proc_t *, int);
void	lwp_userret(lwp_t *);
void	lwp_need_userret(lwp_t *);
void	lwp_free(lwp_t *, bool, bool);
uint64_t lwp_pctr(void);
int	lwp_setprivate(lwp_t *, void *);
int	do_lwp_create(lwp_t *, void *, u_long, lwp_t **, const sigset_t *,
    const stack_t *);

void	lwp_thread_cleanup(lwp_t *);

void	lwpinit_specificdata(void);
int	lwp_specific_key_create(specificdata_key_t *, specificdata_dtor_t);
void	lwp_specific_key_delete(specificdata_key_t);
void	lwp_initspecific(lwp_t *);
void	lwp_finispecific(lwp_t *);
void	*lwp_getspecific(specificdata_key_t);
#if defined(_LWP_API_PRIVATE)
void	*_lwp_getspecific_by_lwp(lwp_t *, specificdata_key_t);
#endif
void	lwp_setspecific(specificdata_key_t, void *);
void	lwp_setspecific_by_lwp(lwp_t *, specificdata_key_t, void *);

/* Syscalls. */
int	lwp_park(clockid_t, int, struct timespec *);
int	lwp_unpark(const lwpid_t *, const u_int);

/* DDB. */
void	lwp_whatis(uintptr_t, void (*)(const char *, ...) __printflike(1, 2));

/*
 * Lock an LWP. XXX _MODULE
 */
static __inline void
lwp_lock(lwp_t *l)
{
	kmutex_t *old = atomic_load_consume(&l->l_mutex);

	/*
	 * Note: mutex_spin_enter() will have posted a read barrier.
	 * Re-test l->l_mutex.  If it has changed, we need to try again.
	 */
	mutex_spin_enter(old);
	while (__predict_false(atomic_load_relaxed(&l->l_mutex) != old)) {
		mutex_spin_exit(old);
		old = atomic_load_consume(&l->l_mutex);
		mutex_spin_enter(old);
	}
}

/*
 * Unlock an LWP. XXX _MODULE
 */
static __inline void
lwp_unlock(lwp_t *l)
{
	mutex_spin_exit(l->l_mutex);
}

static __inline void
lwp_changepri(lwp_t *l, pri_t pri)
{
	KASSERT(mutex_owned(l->l_mutex));

	if (l->l_priority == pri)
		return;

	(*l->l_syncobj->sobj_changepri)(l, pri);
	KASSERT(l->l_priority == pri);
}

static __inline void
lwp_lendpri(lwp_t *l, pri_t pri)
{
	KASSERT(mutex_owned(l->l_mutex));

	(*l->l_syncobj->sobj_lendpri)(l, pri);
	KASSERT(l->l_inheritedprio == pri);
}

static __inline pri_t
lwp_eprio(lwp_t *l)
{
	pri_t pri;

	pri = l->l_priority;
	if ((l->l_flag & LW_SYSTEM) == 0 && l->l_kpriority && pri < PRI_KERNEL)
		pri = (pri >> 1) + l->l_kpribase;
	return MAX(l->l_auxprio, pri);
}

int lwp_create(lwp_t *, struct proc *, vaddr_t, int, void *, size_t,
    void (*)(void *), void *, lwp_t **, int, const sigset_t *, const stack_t *);

/*
 * XXX _MODULE
 * We should provide real stubs for the below that modules can use.
 */

static __inline void
spc_lock(struct cpu_info *ci)
{
	mutex_spin_enter(ci->ci_schedstate.spc_mutex);
}

static __inline void
spc_unlock(struct cpu_info *ci)
{
	mutex_spin_exit(ci->ci_schedstate.spc_mutex);
}

static __inline void
spc_dlock(struct cpu_info *ci1, struct cpu_info *ci2)
{
	struct schedstate_percpu *spc1 = &ci1->ci_schedstate;
	struct schedstate_percpu *spc2 = &ci2->ci_schedstate;

	KASSERT(ci1 != ci2);
	if (ci1 < ci2) {
		mutex_spin_enter(spc1->spc_mutex);
		mutex_spin_enter(spc2->spc_mutex);
	} else {
		mutex_spin_enter(spc2->spc_mutex);
		mutex_spin_enter(spc1->spc_mutex);
	}
}

/*
 * Allow machine-dependent code to override curlwp in <machine/cpu.h> for
 * its own convenience.  Otherwise, we declare it as appropriate.
 */
#if !defined(curlwp)
#if defined(MULTIPROCESSOR)
#define	curlwp		curcpu()->ci_curlwp	/* Current running LWP */
#else
extern struct lwp	*curlwp;		/* Current running LWP */
#endif /* MULTIPROCESSOR */
#endif /* ! curlwp */
#define	curproc		(curlwp->l_proc)

/*
 * This provides a way for <machine/cpu.h> to get l_cpu for curlwp before
 * struct lwp is defined.
 */
static __inline struct cpu_info *
lwp_getcpu(struct lwp *l)
{
	return l->l_cpu;
}

static __inline bool
CURCPU_IDLE_P(void)
{
	struct cpu_info *ci = curcpu();
	return ci->ci_onproc == ci->ci_data.cpu_idlelwp;
}

/*
 * Disable and re-enable preemption.  Only for low-level kernel
 * use.  Device drivers and anything that could potentially be
 * compiled as a module should use kpreempt_disable() and
 * kpreempt_enable().
 */
static __inline void
KPREEMPT_DISABLE(lwp_t *l)
{

	KASSERT(l == curlwp);
	l->l_nopreempt++;
	__insn_barrier();
}

static __inline void
KPREEMPT_ENABLE(lwp_t *l)
{

	KASSERT(l == curlwp);
	KASSERT(l->l_nopreempt > 0);
	__insn_barrier();
	if (--l->l_nopreempt != 0)
		return;
	__insn_barrier();
	if (__predict_false(l->l_dopreempt))
		kpreempt(0);
	__insn_barrier();
}

/* For lwp::l_dopreempt */
#define	DOPREEMPT_ACTIVE	0x01
#define	DOPREEMPT_COUNTED	0x02

/*
 * Prevent curlwp from migrating between CPUs between curlwp_bind and
 * curlwp_bindx. One use case is psref(9) that has a contract that
 * forbids migrations.
 */
static __inline int
curlwp_bind(void)
{
	int bound;

	bound = curlwp->l_pflag & LP_BOUND;
	curlwp->l_pflag |= LP_BOUND;
	__insn_barrier();

	return bound;
}

static __inline void
curlwp_bindx(int bound)
{

	KASSERT(curlwp->l_pflag & LP_BOUND);
	__insn_barrier();
	curlwp->l_pflag ^= bound ^ LP_BOUND;
}

#endif /* _KERNEL */

/* Flags for _lwp_create(), as per Solaris. */
#define	LWP_DETACHED	0x00000040
#define	LWP_SUSPENDED	0x00000080

/* Kernel-internal flags for LWP creation. */
	/*		0x40000000	was LWP_PIDLID */
#define	LWP_VFORK	0x80000000

#endif	/* !_SYS_LWP_H_ */