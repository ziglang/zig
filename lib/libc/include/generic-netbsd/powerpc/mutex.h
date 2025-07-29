/*	$NetBSD: mutex.h,v 1.6.26.1 2023/08/09 17:42:01 martin Exp $	*/

/*-
 * Copyright (c) 2002, 2007 The NetBSD Foundation, Inc.
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

#ifndef _POWERPC_MUTEX_H_
#define	_POWERPC_MUTEX_H_

#include <sys/types.h>

#ifdef __MUTEX_PRIVATE
#include <sys/intr.h>
#include <machine/intr.h>
#endif

struct kmutex {
	union {
#ifdef __MUTEX_PRIVATE
		struct {
			volatile uintptr_t	mtxm_owner;
			ipl_cookie_t		mtxm_ipl;
			__cpu_simple_lock_t	mtxm_lock;
		} m;
#endif
		struct {
			uintptr_t		mtxp_a;
			uint32_t		mtxp_b[2];
		} p;
	} u;
};

#ifdef __MUTEX_PRIVATE

#define	mtx_owner	u.m.mtxm_owner
#define	mtx_ipl		u.m.mtxm_ipl
#define	mtx_lock	u.m.mtxm_lock

#define	__HAVE_SIMPLE_MUTEXES		1
#define	__HAVE_MUTEX_STUBS		1

#define	MUTEX_CAS(p, o, n)		_lock_cas((p), (o), (n))

int	_lock_cas(volatile uintptr_t *, uintptr_t, uintptr_t);

#endif	/* __MUTEX_PRIVATE */

#endif /* _POWERPC_MUTEX_H_ */