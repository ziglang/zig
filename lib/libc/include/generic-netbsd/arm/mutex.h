/*	$NetBSD: mutex.h,v 1.27.4.1 2023/08/09 17:42:01 martin Exp $	*/

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

#ifndef _ARM_MUTEX_H_
#define	_ARM_MUTEX_H_

#include <sys/types.h>

#ifdef _KERNEL
#include <machine/intr.h>
#endif

/*
 * The ARM mutex implementation is troublesome, because pre-v6 ARM lacks a
 * compare-and-swap operation.  However, there aren't any MP pre-v6 ARM
 * systems to speak of.
 *
 * ARMv6 and later, however, does have ldrex/strex, and can thus implement an
 * MP-safe compare-and-swap.
 *
 * So, what we have done is implement simple mutexes using a compare-and-swap.
 * We support pre-ARMv6 by implementing CAS as a restartable atomic sequence
 * that is checked by the IRQ vector.
 *
 */

struct kmutex {
	union {
		/* Adaptive mutex */
		volatile uintptr_t	mtxa_owner;	/* 0-3 */

#ifdef _KERNEL
		/* Spin mutex */
		struct {
			/*
			 * Since the low bit of mtxa_owner is used to flag this
			 * mutex as a spin mutex, we can't use the first byte
			 * or the last byte to store the ipl or lock values.
			 */
			volatile uint8_t	mtxs_dummy;
			ipl_cookie_t		mtxs_ipl;
			__cpu_simple_lock_t	mtxs_lock;
			volatile uint8_t	mtxs_unused;
		} s;
#endif
	} u;
};

#ifdef __MUTEX_PRIVATE

#define	mtx_owner		u.mtxa_owner
#define	mtx_ipl			u.s.mtxs_ipl
#define	mtx_lock		u.s.mtxs_lock

#if 0
#define	__HAVE_MUTEX_STUBS		1
#define	__HAVE_SPIN_MUTEX_STUBS		1
#endif
#define	__HAVE_SIMPLE_MUTEXES		1

#endif	/* __MUTEX_PRIVATE */

__CTASSERT(sizeof(struct kmutex) == sizeof(uintptr_t));

#endif /* _ARM_MUTEX_H_ */