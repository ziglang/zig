/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2005 John Baldwin <jhb@FreeBSD.org>
 * Copyright (c) 2020 The FreeBSD Foundation
 *
 * Portions of this software were developed by Mark Johnston under
 * sponsorship from the FreeBSD Foundation.
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

#ifndef __SYS_BLOCKCOUNT_H__
#define __SYS_BLOCKCOUNT_H__

#ifdef _KERNEL

#include <sys/systm.h>
#include <sys/_blockcount.h>

struct lock_object;

int _blockcount_sleep(blockcount_t *bc, struct lock_object *, const char *wmesg,
    int prio);
void _blockcount_wakeup(blockcount_t *bc, u_int old);

static __inline void
blockcount_init(blockcount_t *bc)
{
	atomic_store_int(&bc->__count, 0);
}

static __inline void
blockcount_acquire(blockcount_t *bc, u_int n)
{
#ifdef INVARIANTS
	u_int old;

	old = atomic_fetchadd_int(&bc->__count, n);
	KASSERT(old + n > old, ("%s: counter overflow %p", __func__, bc));
#else
	atomic_add_int(&bc->__count, n);
#endif
}

static __inline void
blockcount_release(blockcount_t *bc, u_int n)
{
	u_int old;

	atomic_thread_fence_rel();
	old = atomic_fetchadd_int(&bc->__count, -n);
	KASSERT(old >= n, ("%s: counter underflow %p", __func__, bc));
	if (_BLOCKCOUNT_COUNT(old) == n && _BLOCKCOUNT_WAITERS(old))
		_blockcount_wakeup(bc, old);
}

static __inline void
_blockcount_wait(blockcount_t *bc, struct lock_object *lo, const char *wmesg,
    int prio)
{
	KASSERT((prio & ~PRIMASK) == 0, ("%s: invalid prio %x", __func__, prio));

	while (_blockcount_sleep(bc, lo, wmesg, prio) == EAGAIN)
		;
}

#define	blockcount_sleep(bc, lo, wmesg, prio)	\
	_blockcount_sleep((bc), (struct lock_object *)(lo), (wmesg), (prio))
#define	blockcount_wait(bc, lo, wmesg, prio)	\
	_blockcount_wait((bc), (struct lock_object *)(lo), (wmesg), (prio))

#endif /* _KERNEL */
#endif /* !__SYS_BLOCKCOUNT_H__ */