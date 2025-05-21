/*	$NetBSD: mutex.h,v 1.26 2022/10/26 23:21:20 riastradh Exp $	*/

/*-
 * Copyright (c) 2002, 2006, 2007, 2008, 2009, 2019 The NetBSD Foundation, Inc.
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

#ifndef _SYS_MUTEX_H_
#define	_SYS_MUTEX_H_

/*
 * There are 2 types of mutexes:
 *
 *	* Adaptive -- If the lock is already held, the thread attempting
 *	  to acquire the lock determines if the thread that holds it is
 *	  currently running.  If so, it spins, else it sleeps.
 *
 *	* Spin -- If the lock is already held, the thread attempting to
 *	  acquire the lock spins.  The IPL will be raised on entry.
 *
 * Machine dependent code must provide the following:
 *
 *	struct mutex
 *		The actual mutex structure.  This structure is mostly
 *		opaque to machine-independent code; most access are done
 *		through macros.  However, machine-independent code must
 *		be able to access the following members:
 *
 *		uintptr_t		mtx_owner
 *		ipl_cookie_t		mtx_ipl
 *		__cpu_simple_lock_t	mtx_lock
 *
 * If an architecture can be considered 'simple' (no interlock required in
 * the MP case, or no MP) it need only define __HAVE_SIMPLE_MUTEXES and
 * provide the following:
 *
 *	struct mutex
 *
 *		[additionally:]
 *		volatile integer	mtx_id
 *
 * 	MUTEX_CAS(ptr, old, new)
 *		Perform an atomic "compare and swap" operation and
 *		evaluate to true or false according to the success
 *
 * Otherwise, the following must be defined:
 *
 *	MUTEX_INITIALIZE_SPIN(mtx, dodebug, minipl)
 *		Initialize a spin mutex.
 *
 *	MUTEX_INITIALIZE_ADAPTIVE(mtx, dodebug)
 *		Initialize an adaptive mutex.
 *
 *	MUTEX_DESTROY(mtx)
 *		Tear down a mutex.
 *
 *	MUTEX_ADAPTIVE_P(mtx)
 *		Evaluates to true if the mutex is an adaptive mutex.
 *
 *	MUTEX_SPIN_P(mtx)
 *		Evaluates to true if the mutex is a spin mutex.
 *
 *	MUTEX_OWNER(owner)
 *		Returns the owner of the adaptive mutex (LWP address).
 *
 *	MUTEX_OWNED(owner)
 *		Returns non-zero if an adaptive mutex is currently
 *		held by an LWP.
 *
 *	MUTEX_HAS_WAITERS(mtx)
 *		Returns true if the mutex has waiters.
 *
 *	MUTEX_SET_WAITERS(mtx)
 *		Mark the mutex has having waiters.
 *
 *	MUTEX_ACQUIRE(mtx, owner)
 *		Try to acquire an adaptive mutex such that:
 *			if (lock held OR waiters)
 *				return 0;
 *			else
 *				return 1;
 *		Must be MP/interrupt atomic.
 *
 *	MUTEX_RELEASE(mtx)
 *		Release the lock and clear the "has waiters" indication.
 *		Must be interrupt atomic, need not be MP safe.
 *
 *	MUTEX_DEBUG_P(mtx)
 *		Evaluates to true if the mutex is initialized with
 *		dodebug==true.  Only used in the LOCKDEBUG case.
 *
 * Machine dependent code may optionally provide stubs for the following
 * functions to implement the easy (unlocked / no waiters) cases.  If
 * these stubs are provided, __HAVE_MUTEX_STUBS should be defined.
 *
 *	mutex_enter()
 *	mutex_exit()
 *
 * Two additional stubs may be implemented that handle only the spinlock
 * case, primarily for the scheduler.  __HAVE_SPIN_MUTEX_STUBS should be
 * defined if these are provided:
 *
 *	mutex_spin_enter()
 *	mutex_spin_exit()
 */

#if defined(_KERNEL_OPT)
#include "opt_lockdebug.h"
#endif

#if !defined(_KERNEL)
#include <sys/types.h>
#include <sys/inttypes.h>
#endif

typedef enum kmutex_type_t {
	MUTEX_SPIN = 0,		/* To get a spin mutex at IPL_NONE */
	MUTEX_ADAPTIVE = 1,	/* For porting code written for Solaris */
	MUTEX_DEFAULT = 2,	/* The only native, endorsed type */
	MUTEX_DRIVER = 3,	/* For porting code written for Solaris */
	MUTEX_NODEBUG = 4	/* Disables LOCKDEBUG; use with care */
} kmutex_type_t;

typedef struct kmutex kmutex_t;

#if defined(__MUTEX_PRIVATE)

#define	MUTEX_THREAD			((uintptr_t)-16L)

#define	MUTEX_BIT_SPIN			0x01
#define	MUTEX_BIT_WAITERS		0x02

#if defined(LOCKDEBUG)
#define	MUTEX_BIT_NODEBUG		0x04	/* LOCKDEBUG disabled */
#else
#define	MUTEX_BIT_NODEBUG		0x00	/* do nothing */
#endif	/* LOCKDEBUG */

#define	MUTEX_SPIN_IPL(mtx)		((mtx)->mtx_ipl)
#define	MUTEX_SPIN_OLDSPL(ci)		((ci)->ci_mtx_oldspl)

void	mutex_vector_enter(kmutex_t *);
void	mutex_vector_exit(kmutex_t *);
void	mutex_spin_retry(kmutex_t *);
void	mutex_wakeup(kmutex_t *);

#endif	/* __MUTEX_PRIVATE */

#ifdef _KERNEL
#include <sys/intr.h>
#endif

#include <machine/mutex.h>

/*
 * Return true if no spin mutexes are held by the current CPU.
 */
#ifndef MUTEX_NO_SPIN_ACTIVE_P
#define	MUTEX_NO_SPIN_ACTIVE_P(ci)	((ci)->ci_mtx_count == 0)
#endif

#ifdef _KERNEL

void	_mutex_init(kmutex_t *, kmutex_type_t, int, uintptr_t);
void	mutex_init(kmutex_t *, kmutex_type_t, int);
void	mutex_destroy(kmutex_t *);

void	mutex_enter(kmutex_t *);
void	mutex_exit(kmutex_t *);

void	mutex_spin_enter(kmutex_t *);
void	mutex_spin_exit(kmutex_t *);

int	mutex_tryenter(kmutex_t *);

int	mutex_owned(const kmutex_t *);
int	mutex_ownable(const kmutex_t *);
lwp_t	*mutex_owner(const kmutex_t *);
bool	mutex_owner_running(const kmutex_t *);

void	mutex_obj_init(void);
kmutex_t *mutex_obj_alloc(kmutex_type_t, int);
void	mutex_obj_hold(kmutex_t *);
bool	mutex_obj_free(kmutex_t *);
u_int	mutex_obj_refcnt(kmutex_t *);
kmutex_t *mutex_obj_tryalloc(kmutex_type_t, int);

#endif /* _KERNEL */

#endif /* _SYS_MUTEX_H_ */