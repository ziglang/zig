/*	$NetBSD: lock.h,v 1.92 2022/07/24 20:28:39 riastradh Exp $	*/

/*-
 * Copyright (c) 1999, 2000, 2006, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center, by Ross Harvey, and by Andrew Doran.
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

#ifndef	_SYS_LOCK_H_
#define	_SYS_LOCK_H_

#include <sys/stdint.h>
#include <sys/mutex.h>

#include <machine/lock.h>

#ifdef _KERNEL

#ifdef _KERNEL_OPT
#include "opt_lockdebug.h"
#endif

/*
 * From <machine/lock.h>.
 */
#ifndef SPINLOCK_SPIN_HOOK
#define	SPINLOCK_SPIN_HOOK
#endif
#ifndef SPINLOCK_BACKOFF_HOOK
#include <sys/systm.h>
#define	SPINLOCK_BACKOFF_HOOK		nullop(NULL)
#endif
#ifndef	SPINLOCK_BACKOFF_MIN
#define	SPINLOCK_BACKOFF_MIN	4
#endif
#ifndef	SPINLOCK_BACKOFF_MAX
#define	SPINLOCK_BACKOFF_MAX	128
#endif

#define	SPINLOCK_BACKOFF(count)					\
do {								\
	int __i;						\
	for (__i = (count); __i != 0; __i--) {			\
		SPINLOCK_BACKOFF_HOOK;				\
	}							\
	if ((count) < SPINLOCK_BACKOFF_MAX)			\
		(count) += (count);				\
} while (/* CONSTCOND */ 0);

#ifdef LOCKDEBUG
#define	SPINLOCK_SPINOUT(spins)		((spins)++ > 0x0fffffff)
#else
#define	SPINLOCK_SPINOUT(spins)		((void)(spins), 0)
#endif

extern __cpu_simple_lock_t kernel_lock[];

#endif /* _KERNEL */

#endif /* _SYS_LOCK_H_ */