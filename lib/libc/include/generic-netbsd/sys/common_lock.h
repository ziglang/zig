/* $NetBSD: common_lock.h,v 1.2 2017/09/16 23:30:50 christos Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

/*
 * Machine-dependent spin lock operations using the builtin compiler atomic
 * primitives.
 */

#ifndef _SYS_COMMON_LOCK_H_
#define	_SYS_COMMON_LOCK_H_

static __inline int
__SIMPLELOCK_LOCKED_P(const __cpu_simple_lock_t *__ptr)
{
	return *__ptr != __SIMPLELOCK_UNLOCKED;
}

static __inline int
__SIMPLELOCK_UNLOCKED_P(const __cpu_simple_lock_t *__ptr)
{
	return *__ptr == __SIMPLELOCK_UNLOCKED;
}

static __inline void
__cpu_simple_lock_clear(__cpu_simple_lock_t *__ptr)
{
#if 1
	*__ptr = __SIMPLELOCK_UNLOCKED;
#else
	__atomic_store_n(__ptr, __SIMPLELOCK_UNLOCKED, __ATOMIC_RELAXED);
#endif
}

static __inline void
__cpu_simple_lock_set(__cpu_simple_lock_t *__ptr)
{
#if 1
	*__ptr = __SIMPLELOCK_LOCKED;
#else
	__atomic_store_n(__ptr, __SIMPLELOCK_LOCKED, __ATOMIC_RELAXED);
#endif
}

static __inline void __unused
__cpu_simple_lock_init(__cpu_simple_lock_t *__ptr)
{
#if 1
	*__ptr = __SIMPLELOCK_UNLOCKED;
#else
	__atomic_store_n(__ptr, __SIMPLELOCK_UNLOCKED, __ATOMIC_RELAXED);
#endif
}

static __inline void __unused
__cpu_simple_lock(__cpu_simple_lock_t *__ptr)
{
	while (__atomic_exchange_n(__ptr, __SIMPLELOCK_LOCKED, __ATOMIC_ACQUIRE) == __SIMPLELOCK_LOCKED) {
		/* do nothing */
	}
}

static __inline int __unused
__cpu_simple_lock_try(__cpu_simple_lock_t *__ptr)
{
	return __atomic_exchange_n(__ptr, __SIMPLELOCK_LOCKED, __ATOMIC_ACQUIRE) == __SIMPLELOCK_UNLOCKED;
}

static __inline void __unused
__cpu_simple_unlock(__cpu_simple_lock_t *__ptr)
{
	__atomic_store_n(__ptr, __SIMPLELOCK_UNLOCKED, __ATOMIC_RELEASE);
}

#endif /* _SYS_COMMON_LOCK_H_ */