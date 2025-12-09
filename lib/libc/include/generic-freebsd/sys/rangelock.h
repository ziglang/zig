/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2009 Konstantin Belousov <kib@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_SYS_RANGELOCK_H
#define	_SYS_RANGELOCK_H

#include <sys/types.h>
#ifndef _KERNEL
#include <stdbool.h>
#endif

#define	RL_LOCK_READ		0x0001
#define	RL_LOCK_WRITE		0x0002
#define	RL_LOCK_TYPE_MASK	0x0003

struct rl_q_entry;

/*
 * The structure representing the range lock.  Caller may request
 * read or write access to the range of bytes. Access is granted if
 * all existing lock owners are compatible with the request. Two lock
 * owners are compatible if their ranges do not overlap, or both
 * owners are for read.
 */
struct rangelock {
	uintptr_t head;
	bool sleepers;
};

#ifdef _KERNEL

void	 rangelock_init(struct rangelock *lock);
void	 rangelock_destroy(struct rangelock *lock);
void	 rangelock_unlock(struct rangelock *lock, void *cookie);
void	*rangelock_rlock(struct rangelock *lock, vm_ooffset_t start,
    vm_ooffset_t end);
void	*rangelock_tryrlock(struct rangelock *lock, vm_ooffset_t start,
    vm_ooffset_t end);
void	*rangelock_wlock(struct rangelock *lock, vm_ooffset_t start,
    vm_ooffset_t end);
void	*rangelock_trywlock(struct rangelock *lock, vm_ooffset_t start,
    vm_ooffset_t end);
void	rangelock_may_recurse(struct rangelock *lock);
#if defined(INVARIANTS) || defined(INVARIANT_SUPPORT)
void	_rangelock_cookie_assert(void *cookie, int what, const char *file,
    int line);
#endif

#ifdef INVARIANTS
#define	rangelock_cookie_assert_(cookie, what, file, line)	\
	_rangelock_cookie_assert((cookie), (what), (file), (line))
#else
#define	rangelock_cookie_assert_(cookie, what, file, line)		(void)0
#endif

#define	rangelock_cookie_assert(cookie, what)	\
	rangelock_cookie_assert_((cookie), (what), __FILE__, __LINE__)

/*
 * Assertion flags.
 */
#if defined(INVARIANTS) || defined(INVARIANT_SUPPORT)
#define	RCA_LOCKED	0x0001
#define	RCA_RLOCKED	0x0002
#define	RCA_WLOCKED	0x0004
#endif

#endif	/* _KERNEL */

#endif	/* _SYS_RANGELOCK_H */