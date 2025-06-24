/*	$NetBSD: sched.h,v 1.91.2.1 2023/08/09 17:42:01 martin Exp $	*/

/*-
 * Copyright (c) 1999, 2000, 2001, 2002, 2007, 2008, 2019, 2020
 *    The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Ross Harvey, Jason R. Thorpe, Nathan J. Williams, Andrew Doran and
 * Daniel Sieger.
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
 * Copyright (c) 1982, 1986, 1991, 1993
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
 *	@(#)kern_clock.c	8.5 (Berkeley) 1/21/94
 */

#ifndef	_SYS_SCHED_H_
#define	_SYS_SCHED_H_

#include <sys/featuretest.h>
#include <sys/types.h>

#if defined(_KERNEL_OPT)
#include "opt_multiprocessor.h"
#include "opt_lockdebug.h"
#endif

struct sched_param {
	int	sched_priority;
};

/*
 * Scheduling policies required by IEEE Std 1003.1-2001
 */
#define	SCHED_NONE	-1
#define	SCHED_OTHER	0
#define	SCHED_FIFO	1
#define	SCHED_RR	2

#if defined(_NETBSD_SOURCE)
__BEGIN_DECLS

/*
 * Interface of CPU-sets.
 */
typedef struct _cpuset cpuset_t;

#ifndef _KERNEL

#define	cpuset_create()		_cpuset_create()
#define	cpuset_destroy(c)	_cpuset_destroy(c)
#define	cpuset_size(c)		_cpuset_size(c)
#define	cpuset_zero(c)		_cpuset_zero(c)
#define	cpuset_isset(i, c)	_cpuset_isset(i, c)
#define	cpuset_set(i, c)	_cpuset_set(i, c)
#define	cpuset_clr(i, c)	_cpuset_clr(i, c)

cpuset_t *_cpuset_create(void);
void	_cpuset_destroy(cpuset_t *);
void	_cpuset_zero(cpuset_t *);
int	_cpuset_set(cpuid_t, cpuset_t *);
int	_cpuset_clr(cpuid_t, cpuset_t *);
int	_cpuset_isset(cpuid_t, const cpuset_t *);
size_t	_cpuset_size(const cpuset_t *);

#endif

/*
 * Internal affinity and scheduling calls.
 */
int	_sched_getaffinity(pid_t, lwpid_t, size_t, cpuset_t *);
int	_sched_setaffinity(pid_t, lwpid_t, size_t, const cpuset_t *);
int	_sched_getparam(pid_t, lwpid_t, int *, struct sched_param *);
int	_sched_setparam(pid_t, lwpid_t, int, const struct sched_param *);
int	_sched_protect(int);
__END_DECLS

/*
 * CPU states.
 * XXX Not really scheduler state, but no other good place to put
 * it right now, and it really is per-CPU.
 */
#define	CP_USER		0
#define	CP_NICE		1
#define	CP_SYS		2
#define	CP_INTR		3
#define	CP_IDLE		4
#define	CPUSTATES	5

#if defined(_KERNEL) || defined(_KMEMUSER)

#include <sys/time.h>
#include <sys/queue.h>

struct kmutex;

/*
 * Per-CPU scheduler state.  Field markings and the corresponding locks: 
 *
 * s:	splsched, may only be safely accessed by the CPU itself
 * m:	spc_mutex
 * (:	unlocked, stable
 * c:	cpu_lock
 */
struct schedstate_percpu {
	struct kmutex	*spc_mutex;	/* (: lock on below, runnable LWPs */
	struct kmutex	*spc_lwplock;	/* (: general purpose lock for LWPs */
	struct lwp	*spc_migrating;	/* (: migrating LWP */
	struct cpu_info *spc_nextpkg;	/* (: next package 1st for RR */
	psetid_t	spc_psid;	/* c: processor-set ID */
	time_t		spc_lastmod;	/* c: time of last cpu state change */
	volatile int	spc_flags;	/* s: flags; see below */
	u_int		spc_schedticks;	/* s: ticks for schedclock() */
	uint64_t	spc_cp_time[CPUSTATES];/* s: CPU state statistics */
	int		spc_ticks;	/* s: ticks until sched_tick() */
	int		spc_pscnt;	/* s: prof/stat counter */
	int		spc_psdiv;	/* s: prof/stat divisor */
	int		spc_nextskim;	/* s: next time to skim other queues */
	/* Run queue */
	volatile pri_t	spc_curpriority;/* s: usrpri of curlwp */
	pri_t		spc_maxpriority;/* m: highest priority queued */
	u_int		spc_count;	/* m: count of the threads */
	u_int		spc_mcount;	/* m: count of migratable threads */
	uint32_t	spc_bitmap[8];	/* m: bitmap of active queues */
	TAILQ_HEAD(,lwp) *spc_queue;	/* m: queue for each priority */
};

/* spc_flags */
#define	SPCF_SEENRR		0x0001	/* process has seen roundrobin() */
#define	SPCF_SHOULDYIELD	0x0002	/* process should yield the CPU */
#define	SPCF_OFFLINE		0x0004	/* CPU marked offline */
#define	SPCF_RUNNING		0x0008	/* CPU is running */
#define	SPCF_NOINTR		0x0010	/* shielded from interrupts */
#define	SPCF_IDLE		0x0020	/* CPU is currently idle */
#define	SPCF_1STCLASS		0x0040	/* first class scheduling entity */
#define	SPCF_CORE1ST		0x0100	/* first CPU in core */
#define	SPCF_PACKAGE1ST		0x0200	/* first CPU in package */

#define	SPCF_SWITCHCLEAR	(SPCF_SEENRR|SPCF_SHOULDYIELD)

#endif /* defined(_KERNEL) || defined(_KMEMUSER) */

/*
 * Flags passed to the Linux-compatible __clone(2) system call.
 */
#define	CLONE_CSIGNAL		0x000000ff	/* signal to be sent at exit */
#define	CLONE_VM		0x00000100	/* share address space */
#define	CLONE_FS		0x00000200	/* share "file system" info */
#define	CLONE_FILES		0x00000400	/* share file descriptors */
#define	CLONE_SIGHAND		0x00000800	/* share signal actions */
#define	CLONE_PTRACE		0x00002000	/* ptrace(2) continues on
						   child */
#define	CLONE_VFORK		0x00004000	/* parent blocks until child
						   exits */

#endif /* _NETBSD_SOURCE */

#ifdef _KERNEL

extern int schedhz;			/* ideally: 16 */
extern u_int sched_rrticks;
extern u_int sched_pstats_ticks;

struct proc;
struct cpu_info;

/*
 * Common Scheduler Interface.
 */

/* Scheduler initialization */
void		runq_init(void);
void		synch_init(void);
void		sched_init(void);
void		sched_rqinit(void);
void		sched_cpuattach(struct cpu_info *);

/* Time-driven events */
void		sched_tick(struct cpu_info *);
void		schedclock(struct lwp *);
void		sched_schedclock(struct lwp *);
void		sched_pstats(void);
void		sched_lwp_stats(struct lwp *);
void		sched_pstats_hook(struct lwp *, int);

/* Runqueue-related functions */
bool		sched_curcpu_runnable_p(void);
void		sched_dequeue(struct lwp *);
void		sched_enqueue(struct lwp *);
void		sched_preempted(struct lwp *);
void		sched_resched_cpu(struct cpu_info *, pri_t, bool);
void		sched_resched_lwp(struct lwp *, bool);
struct lwp *	sched_nextlwp(void);
void		sched_oncpu(struct lwp *);
void		sched_newts(struct lwp *);
void		sched_vforkexec(struct lwp *, bool);

/* Priority adjustment */
void		sched_nice(struct proc *, int);

/* Handlers of fork and exit */
void		sched_proc_fork(struct proc *, struct proc *);
void		sched_proc_exit(struct proc *, struct proc *);
void		sched_lwp_fork(struct lwp *, struct lwp *);
void		sched_lwp_collect(struct lwp *);

void		sched_slept(struct lwp *);
void		sched_wakeup(struct lwp *);

void		setrunnable(struct lwp *);
void		sched_setrunnable(struct lwp *);

struct cpu_info *sched_takecpu(struct lwp *);
void		sched_print_runqueue(void (*pr)(const char *, ...)
    __printflike(1, 2));

/* Dispatching */
bool		kpreempt(uintptr_t);
void		preempt(void);
bool		preempt_needed(void);
void		preempt_point(void);
void		yield(void);
void		mi_switch(struct lwp *);
void		updatertime(lwp_t *, const struct bintime *);
void		sched_idle(void);
void		suspendsched(void);

int		do_sched_setparam(pid_t, lwpid_t, int, const struct sched_param *);
int		do_sched_getparam(pid_t, lwpid_t, int *, struct sched_param *);

#endif	/* _KERNEL */
#endif	/* _SYS_SCHED_H_ */