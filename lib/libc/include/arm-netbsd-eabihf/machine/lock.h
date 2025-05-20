/*	$NetBSD: lock.h,v 1.39 2021/05/30 02:28:59 joerg Exp $	*/

/*-
 * Copyright (c) 2000, 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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
 *
 * NOTE: The SWP insn used here is available only on ARM architecture
 * version 3 and later (as well as 2a).  What we are going to do is
 * expect that the kernel will trap and emulate the insn.  That will
 * be slow, but give us the atomicity that we need.
 */

#ifndef _ARM_LOCK_H_
#define	_ARM_LOCK_H_

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
__cpu_simple_lock_clear(__cpu_simple_lock_t *__ptr)
{
	*__ptr = __SIMPLELOCK_UNLOCKED;
}

static __inline void
__cpu_simple_lock_set(__cpu_simple_lock_t *__ptr)
{
	*__ptr = __SIMPLELOCK_LOCKED;
}

#if defined(_ARM_ARCH_6)
static __inline unsigned int
__arm_load_exclusive(__cpu_simple_lock_t *__alp)
{
	unsigned int __rv;
	if (/*CONSTCOND*/sizeof(*__alp) == 1) {
		__asm __volatile("ldrexb\t%0,[%1]" : "=r"(__rv) : "r"(__alp));
	} else {
		__asm __volatile("ldrex\t%0,[%1]" : "=r"(__rv) : "r"(__alp));
	}
	return __rv;
}

/* returns 0 on success and 1 on failure */
static __inline unsigned int
__arm_store_exclusive(__cpu_simple_lock_t *__alp, unsigned int __val)
{
	unsigned int __rv;
	if (/*CONSTCOND*/sizeof(*__alp) == 1) {
		__asm __volatile("strexb\t%0,%1,[%2]"
		    : "=&r"(__rv) : "r"(__val), "r"(__alp) : "cc", "memory");
	} else {
		__asm __volatile("strex\t%0,%1,[%2]"
		    : "=&r"(__rv) : "r"(__val), "r"(__alp) : "cc", "memory");
	}
	return __rv;
}
#elif defined(_KERNEL)
static __inline unsigned char
__swp(unsigned char __val, __cpu_simple_lock_t *__ptr)
{
	uint32_t __val32;
	__asm volatile("swpb	%0, %1, [%2]"
	    : "=&r" (__val32) : "r" (__val), "r" (__ptr) : "memory");
	return __val32;
}
#else
/*
 * On MP Cortex, SWP no longer guarantees atomic results.  Thus we pad
 * out SWP so that when the cpu generates an undefined exception we can replace
 * the SWP/MOV instructions with the right LDREX/STREX instructions.
 *
 * This is why we force the SWP into the template needed for LDREX/STREX
 * including the extra instructions and extra register for testing the result.
 */
static __inline int
__swp(int __val, __cpu_simple_lock_t *__ptr)
{
	int __tmp, __rv;
	__asm volatile(
#if 1
	"1:\t"	"swp	%[__rv], %[__val], [%[__ptr]]"
	"\n\t"	"b	2f"
#else
	"1:\t"	"ldrex	%[__rv],[%[__ptr]]"
	"\n\t"	"strex	%[__tmp],%[__val],[%[__ptr]]"
#endif
	"\n\t"	"cmp	%[__tmp],#0"
	"\n\t"	"bne	1b"
	"\n"	"2:"
	    : [__rv] "=&r" (__rv), [__tmp] "=&r" (__tmp)
	    : [__val] "r" (__val), [__ptr] "r" (__ptr) : "cc", "memory");
	return __rv;
}
#endif /* !_ARM_ARCH_6 */

/* load/dmb implies load-acquire */
static __inline void
__arm_load_dmb(void)
{
#if defined(_ARM_ARCH_7)
	__asm __volatile("dmb ish" ::: "memory");
#elif defined(_ARM_ARCH_6)
	__asm __volatile("mcr\tp15,0,%0,c7,c10,5" :: "r"(0) : "memory");
#endif
}

/* dmb/store implies store-release */
static __inline void
__arm_dmb_store(void)
{
#if defined(_ARM_ARCH_7)
	__asm __volatile("dmb ish" ::: "memory");
#elif defined(_ARM_ARCH_6)
	__asm __volatile("mcr\tp15,0,%0,c7,c10,5" :: "r"(0) : "memory");
#endif
}


static __inline void __unused
__cpu_simple_lock_init(__cpu_simple_lock_t *__alp)
{

	*__alp = __SIMPLELOCK_UNLOCKED;
}

#if !defined(__thumb__) || defined(_ARM_ARCH_T2)
static __inline void __unused
__cpu_simple_lock(__cpu_simple_lock_t *__alp)
{
#if defined(_ARM_ARCH_6)
	do {
		/* spin */
	} while (__arm_load_exclusive(__alp) != __SIMPLELOCK_UNLOCKED
		 || __arm_store_exclusive(__alp, __SIMPLELOCK_LOCKED));
	__arm_load_dmb();
#else
	while (__swp(__SIMPLELOCK_LOCKED, __alp) != __SIMPLELOCK_UNLOCKED)
		continue;
#endif
}
#else
void __cpu_simple_lock(__cpu_simple_lock_t *);
#endif

#if !defined(__thumb__) || defined(_ARM_ARCH_T2)
static __inline int __unused
__cpu_simple_lock_try(__cpu_simple_lock_t *__alp)
{
#if defined(_ARM_ARCH_6)
	do {
		if (__arm_load_exclusive(__alp) != __SIMPLELOCK_UNLOCKED) {
			return 0;
		}
	} while (__arm_store_exclusive(__alp, __SIMPLELOCK_LOCKED));
	__arm_load_dmb();
	return 1;
#else
	return (__swp(__SIMPLELOCK_LOCKED, __alp) == __SIMPLELOCK_UNLOCKED);
#endif
}
#else
int __cpu_simple_lock_try(__cpu_simple_lock_t *);
#endif

static __inline void __unused
__cpu_simple_unlock(__cpu_simple_lock_t *__alp)
{

#if defined(_ARM_ARCH_8) && defined(__LP64__)
	if (sizeof(*__alp) == 1) {
		__asm __volatile("stlrb\t%w0, [%1]"
		    :: "r"(__SIMPLELOCK_UNLOCKED), "r"(__alp) : "memory");
	} else {
		__asm __volatile("stlr\t%0, [%1]"
		    :: "r"(__SIMPLELOCK_UNLOCKED), "r"(__alp) : "memory");
	}
#else
	__arm_dmb_store();
	*__alp = __SIMPLELOCK_UNLOCKED;
#endif
}

#endif /* _ARM_LOCK_H_ */