/*	$NetBSD: lock.h,v 1.23 2022/04/09 23:43:20 riastradh Exp $	*/

/*-
 * Copyright (c) 2001, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Wayne Knowles and Andrew Doran.
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
 * Machine-dependent spin lock operations for MIPS processors.
 *
 * Note: R2000/R3000 doesn't have any atomic update instructions; this
 * will cause problems for user applications using this header.
 */

#ifndef _MIPS_LOCK_H_
#define	_MIPS_LOCK_H_

#include <sys/param.h>

#include <sys/atomic.h>

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
	*__ptr = __SIMPLELOCK_UNLOCKED;
}

static __inline void
__cpu_simple_lock_set(__cpu_simple_lock_t *__ptr)
{
	*__ptr = __SIMPLELOCK_LOCKED;
}

#ifndef _HARDKERNEL

static __inline int
__cpu_simple_lock_try(__cpu_simple_lock_t *lp)
{
	unsigned long t0, v0;

	__asm volatile(
		"# -- BEGIN __cpu_simple_lock_try\n"
		"	.set push		\n"
		"	.set mips2		\n"
		"1:	ll	%0, %4		\n"
		"	bnez	%0, 2f		\n"
		"	 nop			\n"
		"	li	%0, %3		\n"
		"	sc	%0, %2		\n"
		"	beqz	%0, 2f		\n"
		"	 nop			\n"
		"	li	%1, 1		\n"
		"	sync			\n"
		"	j	3f		\n"
		"	 nop			\n"
		"	nop			\n"
		"2:	li	%1, 0		\n"
		"3:				\n"
		"	.set pop		\n"
		"# -- END __cpu_simple_lock_try	\n"
		: "=r" (t0), "=r" (v0), "+m" (*lp)
		: "i" (__SIMPLELOCK_LOCKED), "m" (*lp));

	return (v0 != 0);
}

#else	/* !_HARDKERNEL */

u_int	_atomic_cas_uint(volatile u_int *, u_int, u_int);
u_long	_atomic_cas_ulong(volatile u_long *, u_long, u_long);
void *	_atomic_cas_ptr(volatile void *, void *, void *);

static __inline int
__cpu_simple_lock_try(__cpu_simple_lock_t *lp)
{

	/*
	 * Successful _atomic_cas_uint functions as a load-acquire --
	 * on MP systems, it issues sync after the LL/SC CAS succeeds;
	 * on non-MP systems every load is a load-acquire so it's moot.
	 * This pairs with the membar_release and store sequence in
	 * __cpu_simple_unlock that functions as a store-release
	 * operation.
	 *
	 * NOTE: This applies only to _atomic_cas_uint (with the
	 * underscore), in sys/arch/mips/mips/lock_stubs_*.S.  Not true
	 * for atomic_cas_uint (without the underscore), from
	 * common/lib/libc/arch/mips/atomic/atomic_cas.S which does not
	 * imply a load-acquire.  It is unclear why these disagree.
	 */
	return _atomic_cas_uint(lp,
	    __SIMPLELOCK_UNLOCKED, __SIMPLELOCK_LOCKED) ==
	    __SIMPLELOCK_UNLOCKED;
}

#endif	/* _HARDKERNEL */

static __inline void
__cpu_simple_lock_init(__cpu_simple_lock_t *lp)
{

	*lp = __SIMPLELOCK_UNLOCKED;
}

static __inline void
__cpu_simple_lock(__cpu_simple_lock_t *lp)
{

	while (!__cpu_simple_lock_try(lp)) {
		while (*lp == __SIMPLELOCK_LOCKED)
			/* spin */;
	}
}

static __inline void
__cpu_simple_unlock(__cpu_simple_lock_t *lp)
{

	/*
	 * The membar_release and then store functions as a
	 * store-release operation that pairs with the load-acquire
	 * operation in successful __cpu_simple_lock_try.
	 *
	 * Can't use atomic_store_release here because that's not
	 * available in userland at the moment.
	 */
	membar_release();
	*lp = __SIMPLELOCK_UNLOCKED;

#ifdef _MIPS_ARCH_OCTEONP
	/*
	 * On Cavium's recommendation, we issue an extra SYNCW that is
	 * not necessary for correct ordering because apparently stores
	 * can get stuck in Octeon store buffers for hundreds of
	 * thousands of cycles, according to the following note:
	 *
	 *	Programming Notes:
	 *	[...]
	 *	Core A (writer)
	 *	SW R1, DATA
	 *	LI R2, 1
	 *	SYNCW
	 *	SW R2, FLAG
	 *	SYNCW
	 *	[...]
	 *
	 *	The second SYNCW instruction executed by core A is not
	 *	necessary for correctness, but has very important
	 *	performance effects on OCTEON.  Without it, the store
	 *	to FLAG may linger in core A's write buffer before it
	 *	becomes visible to other cores.  (If core A is not
	 *	performing many stores, this may add hundreds of
	 *	thousands of cycles to the flag release time since the
	 *	OCTEON core normally retains stores to attempt to merge
	 *	them before sending the store on the CMB.)
	 *	Applications should include this second SYNCW
	 *	instruction after flag or lock releases.
	 *
	 * Cavium Networks OCTEON Plus CN50XX Hardware Reference
	 * Manual, July 2008, Appendix A, p. 943.
	 * https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/hactive/CN50XX-HRM-V0.99E.pdf
	 *
	 * XXX It might be prudent to put this into
	 * atomic_store_release itself.
	 */
	__asm volatile("syncw" ::: "memory");
#endif
}

#endif /* _MIPS_LOCK_H_ */