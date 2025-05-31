/*	$NetBSD: lockstat.h,v 1.15 2022/02/27 14:16:12 riastradh Exp $	*/

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
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

#ifndef _SYS_LOCKSTAT_H_
#define _SYS_LOCKSTAT_H_

#ifdef _KERNEL_OPT
#include "opt_dtrace.h"
#include <lockstat.h>
#endif

#include <sys/types.h>

#include <sys/ioccom.h>
#include <sys/lock.h>
#include <sys/queue.h>
#include <sys/time.h>

#if defined(_KERNEL) && defined(__HAVE_CPU_COUNTER)
#include <machine/cpu_counter.h>
#endif

/*
 * Interface version.  The interface is not designed to provide
 * compatibility across NetBSD releases.
 */

#define	IOC_LOCKSTAT_GVERSION	_IOR('L', 0, int)

#define	LS_VERSION	5

/*
 * Enable request.  We can limit tracing by the call site and by
 * the lock.  We also specify the number of event buffers to
 * allocate up front, and what kind of events to track.
 */

#define	IOC_LOCKSTAT_ENABLE	_IOW('L', 1, lsenable_t)

#define LE_CALLSITE	0x01		/* track call sites */
#define	LE_ONE_CALLSITE	0x02		/* specific call site */
#define	LE_ONE_LOCK	0x04		/* specific lock */
#define LE_LOCK		0x08		/* track locks */

typedef struct lsenable {
	uintptr_t	le_csstart;	/* callsite start */
	uintptr_t	le_csend;	/* callsite end */
	uintptr_t	le_lockstart;	/* lock address start */
	uintptr_t	le_lockend;	/* lock address end */
	uintptr_t	le_nbufs;	/* buffers to allocate, 0 = default */
	u_int		le_flags;	/* request flags */
	u_int		le_mask;	/* event mask (LB_*) */
} lsenable_t;

/*
 * Disable request.
 */

#define	IOC_LOCKSTAT_DISABLE	_IOR('L', 2, lsdisable_t)

typedef struct lsdisable {
	size_t		ld_size;	/* buffer space allocated */
	struct timespec	ld_time;	/* time spent enabled */
	uint64_t	ld_freq[64];	/* counter HZ by CPU number */
} lsdisable_t;

/*
 * Event buffers returned from reading from the devices.
 */

/*
 * Event types, for lockstat_event().  Stored in lb_flags but should be
 * meaningless to the consumer, also provided with the enable request
 * in le_mask.
 */
#define	LB_SPIN			0x00000001
#define	LB_SLEEP1		0x00000002
#define	LB_SLEEP2		0x00000003
#define	LB_NEVENT		0x00000003
#define	LB_EVENT_MASK		0x000000ff

/*
 * Lock types, the only part of lb_flags that should be inspected.  Also
 * provided with the enable request in le_mask.
 */
#define	LB_ADAPTIVE_MUTEX	0x00000100
#define	LB_SPIN_MUTEX		0x00000200
#define	LB_RWLOCK		0x00000300
#define	LB_NOPREEMPT		0x00000400
#define	LB_KERNEL_LOCK		0x00000500
#define	LB_MISC			0x00000600
#define	LB_NLOCK		0x00000600
#define	LB_LOCK_MASK		0x0000ff00
#define	LB_LOCK_SHIFT		8

#define	LB_DTRACE		0x00010000

typedef struct lsbuf {
	union {
		LIST_ENTRY(lsbuf) list;
		SLIST_ENTRY(lsbuf) slist;
		TAILQ_ENTRY(lsbuf) tailq;
	} lb_chain;
	uintptr_t	lb_lock;		/* lock address */
	uintptr_t	lb_callsite;		/* call site */
	uint64_t	lb_times[LB_NEVENT];	/* cumulative times */
	uint32_t	lb_counts[LB_NEVENT];	/* count of events */
	uint16_t	lb_flags;		/* lock type */
	uint16_t	lb_cpu;			/* CPU number */
} lsbuf_t;

/*
 * Tracing stubs used by lock providers.
 */

#if defined(_KERNEL) && defined(__HAVE_CPU_COUNTER) && NLOCKSTAT > 0

#define	LOCKSTAT_EVENT(flag, lock, type, count, time)			\
do {									\
	if (__predict_false(flag))					\
		lockstat_event((uintptr_t)(lock),			\
		    (uintptr_t)__builtin_return_address(0),		\
		    (type), (count), (time));				\
} while (/* CONSTCOND */ 0);

#define	LOCKSTAT_EVENT_RA(flag, lock, type, count, time, ra)		\
do {									\
	if (__predict_false(flag))					\
		lockstat_event((uintptr_t)(lock), (uintptr_t)ra,	\
		    (type), (count), (time));				\
} while (/* CONSTCOND */ 0);

#define	LOCKSTAT_TIMER(name)	uint64_t name = 0
#define	LOCKSTAT_COUNTER(name)	uint64_t name = 0
#define	LOCKSTAT_FLAG(name)	int name
#define	LOCKSTAT_ENTER(name)	name = atomic_load_relaxed(&lockstat_enabled)
#define	LOCKSTAT_EXIT(name)

#define	LOCKSTAT_START_TIMER(flag, name)				\
do {									\
	if (__predict_false(flag))					\
		(name) -= cpu_counter();				\
} while (/* CONSTCOND */ 0)

#define	LOCKSTAT_STOP_TIMER(flag, name)					\
do {									\
	if (__predict_false(flag))					\
		(name) += cpu_counter();				\
} while (/* CONSTCOND */ 0)

#define	LOCKSTAT_COUNT(name, inc)					\
do {									\
	(name) += (inc);						\
} while (/* CONSTCOND */ 0)

void	lockstat_event(uintptr_t, uintptr_t, u_int, u_int, uint64_t);

#else

#define	LOCKSTAT_FLAG(name)					/* nothing */
#define	LOCKSTAT_ENTER(name)					/* nothing */
#define	LOCKSTAT_EXIT(name)					/* nothing */
#define	LOCKSTAT_EVENT(flag, lock, type, count, time)		/* nothing */
#define	LOCKSTAT_EVENT_RA(flag, lock, type, count, time, ra)	/* nothing */
#define	LOCKSTAT_TIMER(void)					/* nothing */
#define	LOCKSTAT_COUNTER(void)					/* nothing */
#define	LOCKSTAT_START_TIMER(flag, void)			/* nothing */
#define	LOCKSTAT_STOP_TIMER(flag, void)				/* nothing */
#define	LOCKSTAT_COUNT(name, int)				/* nothing */

#endif

#ifdef KDTRACE_HOOKS
extern volatile u_int lockstat_dtrace_enabled;
#define KDTRACE_LOCKSTAT_ENABLED lockstat_dtrace_enabled
#define LS_COMPRESS(f) \
    ((((f) & 0x3) | (((f) & 0x700) >> 6)) & (LS_NPROBES - 1))
#define	LS_NPROBES	0x20	/* 5 bits */

extern uint32_t	lockstat_probemap[];
extern void	(*lockstat_probe_func)(uint32_t, uintptr_t, uintptr_t,
    uintptr_t, uintptr_t, uintptr_t);

void		lockstat_probe_stub(uint32_t, uintptr_t, uintptr_t,
    uintptr_t, uintptr_t, uintptr_t);
#else
#define KDTRACE_LOCKSTAT_ENABLED 0
#endif

#if defined(_KERNEL) && NLOCKSTAT > 0
extern __cpu_simple_lock_t lockstat_enabled_lock;
extern volatile u_int	lockstat_enabled;
extern volatile u_int	lockstat_dev_enabled;

#define LOCKSTAT_ENABLED_UPDATE_BEGIN() do				    \
{									    \
	__cpu_simple_lock(&lockstat_enabled_lock);			    \
} while (/*CONSTCOND*/0)

#define LOCKSTAT_ENABLED_UPDATE_END() do				    \
{									    \
	atomic_store_relaxed(&lockstat_enabled,				    \
	    lockstat_dev_enabled | KDTRACE_LOCKSTAT_ENABLED);		    \
	__cpu_simple_unlock(&lockstat_enabled_lock);			    \
} while (/*CONSTCOND*/0)

#endif

#endif	/* _SYS_LOCKSTAT_H_ */