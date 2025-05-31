/*	$NetBSD: mutex.h,v 1.4.4.1 2023/08/09 17:42:03 martin Exp $	*/

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

#ifndef _RISCV_MUTEX_H_
#define	_RISCV_MUTEX_H_

#include <sys/types.h>

#ifndef __MUTEX_PRIVATE

struct kmutex {
	uintptr_t	mtx_pad1;
};

#else	/* __MUTEX_PRIVATE */

#include <sys/cdefs.h>

#include <sys/param.h>

#include <machine/intr.h>

struct kmutex {
	volatile uintptr_t	mtx_owner;
};

#ifdef _LP64
#define MTX_ASMOP_SFX ".d"		// doubleword atomic op
#else
#define MTX_ASMOP_SFX ".w"		// word atomic op
#endif

#define	MTX_LOCK			__BIT(8)	// just one bit
#define	MTX_IPL				__BITS(7,4)	// only need 4 bits

#undef MUTEX_SPIN_IPL			// override <sys/mutex.h>
#define	MUTEX_SPIN_IPL(a)		riscv_mutex_spin_ipl(a)
#define	MUTEX_INITIALIZE_SPIN_IPL(a,b)	riscv_mutex_initialize_spin_ipl(a,b)
#define MUTEX_SPINBIT_LOCK_INIT(a)	riscv_mutex_spinbit_lock_init(a)
#define MUTEX_SPINBIT_LOCK_TRY(a)	riscv_mutex_spinbit_lock_try(a)
#define MUTEX_SPINBIT_LOCKED_P(a)	riscv_mutex_spinbit_locked_p(a)
#define MUTEX_SPINBIT_LOCK_UNLOCK(a)	riscv_mutex_spinbit_lock_unlock(a)

static inline ipl_cookie_t
riscv_mutex_spin_ipl(kmutex_t *__mtx)
{
	return (ipl_cookie_t){._spl = __SHIFTOUT(__mtx->mtx_owner, MTX_IPL)};
}

static inline void
riscv_mutex_initialize_spin_ipl(kmutex_t *__mtx, int ipl)
{
	__mtx->mtx_owner = (__mtx->mtx_owner & ~MTX_IPL)
	    | __SHIFTIN(ipl, MTX_IPL);
}

static inline void
riscv_mutex_spinbit_lock_init(kmutex_t *__mtx)
{
	__mtx->mtx_owner &= ~MTX_LOCK;
}

static inline bool
riscv_mutex_spinbit_locked_p(const kmutex_t *__mtx)
{
	return (__mtx->mtx_owner & MTX_LOCK) != 0;
}

static inline bool
riscv_mutex_spinbit_lock_try(kmutex_t *__mtx)
{
	uintptr_t __old;
	__asm __volatile(
		"amoor" MTX_ASMOP_SFX ".aq\t%0, %1, (%2)"
	   :	"=r"(__old)
	   :	"r"(MTX_LOCK), "r"(__mtx));
	return (__old & MTX_LOCK) == 0;
}

static inline void
riscv_mutex_spinbit_lock_unlock(kmutex_t *__mtx)
{
	__asm __volatile(
		"amoand" MTX_ASMOP_SFX ".rl\tx0, %0, (%1)"
	   ::	"r"(~MTX_LOCK), "r"(__mtx));
}

#if 0
#define	__HAVE_MUTEX_STUBS		1
#define	__HAVE_SPIN_MUTEX_STUBS		1
#endif
#define	__HAVE_SIMPLE_MUTEXES		1

#endif	/* __MUTEX_PRIVATE */

#endif /* _RISCV_MUTEX_H_ */