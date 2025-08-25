/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2005 John Baldwin <jhb@FreeBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef __SYS_REFCOUNT_H__
#define __SYS_REFCOUNT_H__

#include <machine/atomic.h>

#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/systm.h>
#else
#include <stdbool.h>
#define	KASSERT(exp, msg)	/* */
#endif

#define	REFCOUNT_SATURATED(val)		(((val) & (1U << 31)) != 0)
#define	REFCOUNT_SATURATION_VALUE	(3U << 30)

/*
 * Attempt to handle reference count overflow and underflow.  Force the counter
 * to stay at the saturation value so that a counter overflow cannot trigger
 * destruction of the containing object and instead leads to a less harmful
 * memory leak.
 */
static __inline void
_refcount_update_saturated(volatile u_int *count)
{
#ifdef INVARIANTS
	panic("refcount %p wraparound", count);
#else
	atomic_store_int(count, REFCOUNT_SATURATION_VALUE);
#endif
}

static __inline void
refcount_init(volatile u_int *count, u_int value)
{
	KASSERT(!REFCOUNT_SATURATED(value),
	    ("invalid initial refcount value %u", value));
	atomic_store_int(count, value);
}

static __inline u_int
refcount_load(volatile u_int *count)
{
	return (atomic_load_int(count));
}

static __inline u_int
refcount_acquire(volatile u_int *count)
{
	u_int old;

	old = atomic_fetchadd_int(count, 1);
	if (__predict_false(REFCOUNT_SATURATED(old)))
		_refcount_update_saturated(count);

	return (old);
}

static __inline u_int
refcount_acquiren(volatile u_int *count, u_int n)
{
	u_int old;

	KASSERT(n < REFCOUNT_SATURATION_VALUE / 2,
	    ("refcount_acquiren: n=%u too large", n));
	old = atomic_fetchadd_int(count, n);
	if (__predict_false(REFCOUNT_SATURATED(old)))
		_refcount_update_saturated(count);

	return (old);
}

static __inline __result_use_check bool
refcount_acquire_checked(volatile u_int *count)
{
	u_int old;

	old = atomic_load_int(count);
	for (;;) {
		if (__predict_false(REFCOUNT_SATURATED(old + 1)))
			return (false);
		if (__predict_true(atomic_fcmpset_int(count, &old,
		    old + 1) == 1))
			return (true);
	}
}

/*
 * This functions returns non-zero if the refcount was
 * incremented. Else zero is returned.
 */
static __inline __result_use_check bool
refcount_acquire_if_gt(volatile u_int *count, u_int n)
{
	u_int old;

	old = atomic_load_int(count);
	for (;;) {
		if (old <= n)
			return (false);
		if (__predict_false(REFCOUNT_SATURATED(old)))
			return (true);
		if (atomic_fcmpset_int(count, &old, old + 1))
			return (true);
	}
}

static __inline __result_use_check bool
refcount_acquire_if_not_zero(volatile u_int *count)
{

	return (refcount_acquire_if_gt(count, 0));
}

static __inline bool
refcount_releasen(volatile u_int *count, u_int n)
{
	u_int old;

	KASSERT(n < REFCOUNT_SATURATION_VALUE / 2,
	    ("refcount_releasen: n=%u too large", n));

	atomic_thread_fence_rel();
	old = atomic_fetchadd_int(count, -n);
	if (__predict_false(old < n || REFCOUNT_SATURATED(old))) {
		_refcount_update_saturated(count);
		return (false);
	}
	if (old > n)
		return (false);

	/*
	 * Last reference.  Signal the user to call the destructor.
	 *
	 * Ensure that the destructor sees all updates. This synchronizes with
	 * release fences from all routines which drop the count.
	 */
	atomic_thread_fence_acq();
	return (true);
}

static __inline bool
refcount_release(volatile u_int *count)
{

	return (refcount_releasen(count, 1));
}

#define	_refcount_release_if_cond(cond, name)				\
static __inline __result_use_check bool					\
_refcount_release_if_##name(volatile u_int *count, u_int n)		\
{									\
	u_int old;							\
									\
	KASSERT(n > 0, ("%s: zero increment", __func__));		\
	old = atomic_load_int(count);					\
	for (;;) {							\
		if (!(cond))						\
			return (false);					\
		if (__predict_false(REFCOUNT_SATURATED(old)))		\
			return (false);					\
		if (atomic_fcmpset_rel_int(count, &old, old - 1))	\
			return (true);					\
	}								\
}
_refcount_release_if_cond(old > n, gt)
_refcount_release_if_cond(old == n, eq)

static __inline __result_use_check bool
refcount_release_if_gt(volatile u_int *count, u_int n)
{

	return (_refcount_release_if_gt(count, n));
}

static __inline __result_use_check bool
refcount_release_if_last(volatile u_int *count)
{

	if (_refcount_release_if_eq(count, 1)) {
		/* See the comment in refcount_releasen(). */
		atomic_thread_fence_acq();
		return (true);
	}
	return (false);
}

static __inline __result_use_check bool
refcount_release_if_not_last(volatile u_int *count)
{

	return (_refcount_release_if_gt(count, 1));
}

#endif /* !__SYS_REFCOUNT_H__ */