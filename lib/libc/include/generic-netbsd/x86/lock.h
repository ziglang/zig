/*	$NetBSD: lock.h,v 1.29 2022/02/12 17:17:54 riastradh Exp $	*/

/*-
 * Copyright (c) 2000, 2006 The NetBSD Foundation, Inc.
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

/*
 * Machine-dependent spin lock operations.
 */

#ifndef _X86_LOCK_H_
#define	_X86_LOCK_H_

#include <sys/param.h>

static __inline int
__SIMPLELOCK_LOCKED_P(const __cpu_simple_lock_t *__ptr)
{
	return *__ptr == __SIMPLELOCK_LOCKED;
}

static __inline int
__SIMPLELOCK_UNLOCKED_P(const __cpu_simple_lock_t *__ptr)
{
	return *__ptr == __SIMPLELOCK_UNLOCKED;
}

static __inline void
__cpu_simple_lock_set(__cpu_simple_lock_t *__ptr)
{

	*__ptr = __SIMPLELOCK_LOCKED;
}

static __inline void
__cpu_simple_lock_clear(__cpu_simple_lock_t *__ptr)
{

	*__ptr = __SIMPLELOCK_UNLOCKED;
}

#ifdef _HARDKERNEL
# include <machine/cpufunc.h>
# define SPINLOCK_SPIN_HOOK	/* nothing */
# ifdef SPINLOCK_BACKOFF_HOOK
#  undef SPINLOCK_BACKOFF_HOOK
# endif
# define SPINLOCK_BACKOFF_HOOK	x86_pause()
# define SPINLOCK_INLINE
#else /* !_HARDKERNEL */
# define SPINLOCK_BODY
# define SPINLOCK_INLINE static __inline __unused
#endif /* _HARDKERNEL */

SPINLOCK_INLINE void	__cpu_simple_lock_init(__cpu_simple_lock_t *);
SPINLOCK_INLINE void	__cpu_simple_lock(__cpu_simple_lock_t *);
SPINLOCK_INLINE int	__cpu_simple_lock_try(__cpu_simple_lock_t *);
SPINLOCK_INLINE void	__cpu_simple_unlock(__cpu_simple_lock_t *);

#ifdef SPINLOCK_BODY
SPINLOCK_INLINE void
__cpu_simple_lock_init(__cpu_simple_lock_t *lockp)
{

	*lockp = __SIMPLELOCK_UNLOCKED;
}

SPINLOCK_INLINE int
__cpu_simple_lock_try(__cpu_simple_lock_t *lockp)
{
	uint8_t val;

	val = __SIMPLELOCK_LOCKED;
	__asm volatile ("xchgb %0,(%2)" : 
	    "=qQ" (val)
	    :"0" (val), "r" (lockp));
	__insn_barrier();
	return val == __SIMPLELOCK_UNLOCKED;
}

SPINLOCK_INLINE void
__cpu_simple_lock(__cpu_simple_lock_t *lockp)
{

	while (!__cpu_simple_lock_try(lockp))
		/* nothing */;
	__insn_barrier();
}

/*
 * Note on x86 memory ordering
 *
 * When releasing a lock we must ensure that no stores or loads from within
 * the critical section are re-ordered by the CPU to occur outside of it:
 * they must have completed and be visible to other processors once the lock
 * has been released.
 *
 * NetBSD usually runs with the kernel mapped (via MTRR) in a WB (write
 * back) memory region.  In that case, memory ordering on x86 platforms
 * looks like this:
 *
 * i386		All loads/stores occur in instruction sequence.
 *
 * i486		All loads/stores occur in instruction sequence.  In
 * Pentium	exceptional circumstances, loads can be re-ordered around
 *		stores, but for the purposes of releasing a lock it does
 *		not matter.  Stores may not be immediately visible to other
 *		processors as they can be buffered.  However, since the
 *		stores are buffered in order the lock release will always be
 *		the last operation in the critical section that becomes
 *		visible to other CPUs.
 *
 * Pentium Pro	The "Intel 64 and IA-32 Architectures Software Developer's
 * onwards	Manual" volume 3A (order number 248966) says that (1) "Reads
 *		can be carried out speculatively and in any order" and (2)
 *		"Reads can pass buffered stores, but the processor is
 *		self-consistent.".  This would be a problem for the below,
 *		and would mandate a locked instruction cycle or load fence
 *		before releasing the simple lock.
 *
 *		The "Intel Pentium 4 Processor Optimization" guide (order
 *		number 253668-022US) says: "Loads can be moved before stores
 *		that occurred earlier in the program if they are not
 *		predicted to load from the same linear address.".  This is
 *		not a problem since the only loads that can be re-ordered
 *		take place once the lock has been released via a store.
 *
 *		The above two documents seem to contradict each other,
 *		however with the exception of early steppings of the Pentium
 *		Pro, the second document is closer to the truth: a store
 *		will always act as a load fence for all loads that precede
 *		the store in instruction order.
 *
 *		Again, note that stores can be buffered and will not always
 *		become immediately visible to other CPUs: they are however
 *		buffered in order.
 *
 * AMD64	Stores occur in order and are buffered.  Loads can be
 *		reordered, however stores act as load fences, meaning that
 *		loads can not be reordered around stores.
 */
SPINLOCK_INLINE void
__cpu_simple_unlock(__cpu_simple_lock_t *lockp)
{

	__insn_barrier();
	*lockp = __SIMPLELOCK_UNLOCKED;
}

#endif	/* SPINLOCK_BODY */

#endif /* _X86_LOCK_H_ */