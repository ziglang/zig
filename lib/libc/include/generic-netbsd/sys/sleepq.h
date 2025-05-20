/*	$NetBSD: sleepq.h,v 1.36 2022/10/26 23:24:59 riastradh Exp $	*/

/*-
 * Copyright (c) 2002, 2006, 2007, 2008, 2009, 2019, 2020
 *     The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe and Andrew Doran.
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

#ifndef	_SYS_SLEEPQ_H_
#define	_SYS_SLEEPQ_H_

#include <sys/lwp.h>
#include <sys/mutex.h>
#include <sys/pool.h>
#include <sys/queue.h>
#include <sys/sched.h>
#include <sys/syncobj.h>
#include <sys/param.h>

/*
 * Generic sleep queues.
 */

typedef struct sleepq sleepq_t;

void	sleepq_init(sleepq_t *);
void	sleepq_remove(sleepq_t *, lwp_t *);
void	sleepq_enqueue(sleepq_t *, wchan_t, const char *, struct syncobj *,
	    bool);
void	sleepq_transfer(lwp_t *, sleepq_t *, sleepq_t *, wchan_t, const char *,
	    struct syncobj *, kmutex_t *, bool);
void	sleepq_uncatch(lwp_t *);
void	sleepq_unsleep(lwp_t *, bool);
void	sleepq_timeout(void *);
void	sleepq_wake(sleepq_t *, wchan_t, u_int, kmutex_t *);
int	sleepq_abort(kmutex_t *, int);
void	sleepq_changepri(lwp_t *, pri_t);
void	sleepq_lendpri(lwp_t *, pri_t);
int	sleepq_block(int, bool, struct syncobj *);

#ifdef _KERNEL

#include <sys/kernel.h>

typedef union {
	kmutex_t	lock;
	uint8_t		pad[COHERENCY_UNIT];
} sleepqlock_t;

/*
 * Return non-zero if it is unsafe to sleep.
 *
 * XXX This only exists because panic() is broken.
 */
static __inline bool
sleepq_dontsleep(lwp_t *l)
{

	return cold || (doing_shutdown && (panicstr || CURCPU_IDLE_P()));
}

/*
 * Prepare to block on a sleep queue, after which any interlock can be
 * safely released.
 */
static __inline void
sleepq_enter(sleepq_t *sq, lwp_t *l, kmutex_t *mp)
{

	/*
	 * Acquire the per-LWP mutex and lend it ours sleep queue lock.
	 * Once interlocked, we can release the kernel lock.
	 */
	lwp_lock(l);
	lwp_unlock_to(l, mp);
	KERNEL_UNLOCK_ALL(NULL, &l->l_biglocks);
}

#endif

#include <sys/sleeptab.h>

#endif	/* _SYS_SLEEPQ_H_ */