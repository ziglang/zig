/*	$NetBSD: atomic.h,v 1.26 2022/07/31 11:28:46 martin Exp $	*/

/*-
 * Copyright (c) 2007, 2008 The NetBSD Foundation, Inc.
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

#ifndef _SYS_ATOMIC_H_
#define	_SYS_ATOMIC_H_

#include <sys/types.h>
#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <stdint.h>
#endif

#if defined(_KERNEL) && defined(_KERNEL_OPT)
#include "opt_kasan.h"
#include "opt_kcsan.h"
#include "opt_kmsan.h"
#endif

#if defined(KASAN)
#define ATOMIC_PROTO_ADD(name, tret, targ1, targ2) \
	void kasan_atomic_add_##name(volatile targ1 *, targ2); \
	tret kasan_atomic_add_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_AND(name, tret, targ1, targ2) \
	void kasan_atomic_and_##name(volatile targ1 *, targ2); \
	tret kasan_atomic_and_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_OR(name, tret, targ1, targ2) \
	void kasan_atomic_or_##name(volatile targ1 *, targ2); \
	tret kasan_atomic_or_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_CAS(name, tret, targ1, targ2) \
	tret kasan_atomic_cas_##name(volatile targ1 *, targ2, targ2); \
	tret kasan_atomic_cas_##name##_ni(volatile targ1 *, targ2, targ2)
#define ATOMIC_PROTO_SWAP(name, tret, targ1, targ2) \
	tret kasan_atomic_swap_##name(volatile targ1 *, targ2)
#define ATOMIC_PROTO_DEC(name, tret, targ1) \
	void kasan_atomic_dec_##name(volatile targ1 *); \
	tret kasan_atomic_dec_##name##_nv(volatile targ1 *)
#define ATOMIC_PROTO_INC(name, tret, targ1) \
	void kasan_atomic_inc_##name(volatile targ1 *); \
	tret kasan_atomic_inc_##name##_nv(volatile targ1 *)
#elif defined(KCSAN)
#define ATOMIC_PROTO_ADD(name, tret, targ1, targ2) \
	void kcsan_atomic_add_##name(volatile targ1 *, targ2); \
	tret kcsan_atomic_add_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_AND(name, tret, targ1, targ2) \
	void kcsan_atomic_and_##name(volatile targ1 *, targ2); \
	tret kcsan_atomic_and_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_OR(name, tret, targ1, targ2) \
	void kcsan_atomic_or_##name(volatile targ1 *, targ2); \
	tret kcsan_atomic_or_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_CAS(name, tret, targ1, targ2) \
	tret kcsan_atomic_cas_##name(volatile targ1 *, targ2, targ2); \
	tret kcsan_atomic_cas_##name##_ni(volatile targ1 *, targ2, targ2)
#define ATOMIC_PROTO_SWAP(name, tret, targ1, targ2) \
	tret kcsan_atomic_swap_##name(volatile targ1 *, targ2)
#define ATOMIC_PROTO_DEC(name, tret, targ1) \
	void kcsan_atomic_dec_##name(volatile targ1 *); \
	tret kcsan_atomic_dec_##name##_nv(volatile targ1 *)
#define ATOMIC_PROTO_INC(name, tret, targ1) \
	void kcsan_atomic_inc_##name(volatile targ1 *); \
	tret kcsan_atomic_inc_##name##_nv(volatile targ1 *)
#elif defined(KMSAN)
#define ATOMIC_PROTO_ADD(name, tret, targ1, targ2) \
	void kmsan_atomic_add_##name(volatile targ1 *, targ2); \
	tret kmsan_atomic_add_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_AND(name, tret, targ1, targ2) \
	void kmsan_atomic_and_##name(volatile targ1 *, targ2); \
	tret kmsan_atomic_and_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_OR(name, tret, targ1, targ2) \
	void kmsan_atomic_or_##name(volatile targ1 *, targ2); \
	tret kmsan_atomic_or_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_CAS(name, tret, targ1, targ2) \
	tret kmsan_atomic_cas_##name(volatile targ1 *, targ2, targ2); \
	tret kmsan_atomic_cas_##name##_ni(volatile targ1 *, targ2, targ2)
#define ATOMIC_PROTO_SWAP(name, tret, targ1, targ2) \
	tret kmsan_atomic_swap_##name(volatile targ1 *, targ2)
#define ATOMIC_PROTO_DEC(name, tret, targ1) \
	void kmsan_atomic_dec_##name(volatile targ1 *); \
	tret kmsan_atomic_dec_##name##_nv(volatile targ1 *)
#define ATOMIC_PROTO_INC(name, tret, targ1) \
	void kmsan_atomic_inc_##name(volatile targ1 *); \
	tret kmsan_atomic_inc_##name##_nv(volatile targ1 *)
#else
#define ATOMIC_PROTO_ADD(name, tret, targ1, targ2) \
	void atomic_add_##name(volatile targ1 *, targ2); \
	tret atomic_add_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_AND(name, tret, targ1, targ2) \
	void atomic_and_##name(volatile targ1 *, targ2); \
	tret atomic_and_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_OR(name, tret, targ1, targ2) \
	void atomic_or_##name(volatile targ1 *, targ2); \
	tret atomic_or_##name##_nv(volatile targ1 *, targ2)
#define ATOMIC_PROTO_CAS(name, tret, targ1, targ2) \
	tret atomic_cas_##name(volatile targ1 *, targ2, targ2); \
	tret atomic_cas_##name##_ni(volatile targ1 *, targ2, targ2)
#define ATOMIC_PROTO_SWAP(name, tret, targ1, targ2) \
	tret atomic_swap_##name(volatile targ1 *, targ2)
#define ATOMIC_PROTO_DEC(name, tret, targ1) \
	void atomic_dec_##name(volatile targ1 *); \
	tret atomic_dec_##name##_nv(volatile targ1 *)
#define ATOMIC_PROTO_INC(name, tret, targ1) \
	void atomic_inc_##name(volatile targ1 *); \
	tret atomic_inc_##name##_nv(volatile targ1 *)
#endif

__BEGIN_DECLS

ATOMIC_PROTO_ADD(32, uint32_t, uint32_t, int32_t);
ATOMIC_PROTO_ADD(64, uint64_t, uint64_t, int64_t);
ATOMIC_PROTO_ADD(int, unsigned int, unsigned int, int);
ATOMIC_PROTO_ADD(long, unsigned long, unsigned long, long);
ATOMIC_PROTO_ADD(ptr, void *, void, ssize_t);

ATOMIC_PROTO_AND(32, uint32_t, uint32_t, uint32_t);
ATOMIC_PROTO_AND(64, uint64_t, uint64_t, uint64_t);
ATOMIC_PROTO_AND(uint, unsigned int, unsigned int, unsigned int);
ATOMIC_PROTO_AND(ulong, unsigned long, unsigned long, unsigned long);

ATOMIC_PROTO_OR(32, uint32_t, uint32_t, uint32_t);
ATOMIC_PROTO_OR(64, uint64_t, uint64_t, uint64_t);
ATOMIC_PROTO_OR(uint, unsigned int, unsigned int, unsigned int);
ATOMIC_PROTO_OR(ulong, unsigned long, unsigned long, unsigned long);

ATOMIC_PROTO_CAS(32, uint32_t, uint32_t, uint32_t);
ATOMIC_PROTO_CAS(64, uint64_t, uint64_t, uint64_t);
ATOMIC_PROTO_CAS(uint, unsigned int, unsigned int, unsigned int);
ATOMIC_PROTO_CAS(ulong, unsigned long, unsigned long, unsigned long);
ATOMIC_PROTO_CAS(ptr, void *, void, void *);

ATOMIC_PROTO_SWAP(32, uint32_t, uint32_t, uint32_t);
ATOMIC_PROTO_SWAP(64, uint64_t, uint64_t, uint64_t);
ATOMIC_PROTO_SWAP(uint, unsigned int, unsigned int, unsigned int);
ATOMIC_PROTO_SWAP(ulong, unsigned long, unsigned long, unsigned long);
ATOMIC_PROTO_SWAP(ptr, void *, void, void *);

ATOMIC_PROTO_DEC(32, uint32_t, uint32_t);
ATOMIC_PROTO_DEC(64, uint64_t, uint64_t);
ATOMIC_PROTO_DEC(uint, unsigned int, unsigned int);
ATOMIC_PROTO_DEC(ulong, unsigned long, unsigned long);
ATOMIC_PROTO_DEC(ptr, void *, void);

ATOMIC_PROTO_INC(32, uint32_t, uint32_t);
ATOMIC_PROTO_INC(64, uint64_t, uint64_t);
ATOMIC_PROTO_INC(uint, unsigned int, unsigned int);
ATOMIC_PROTO_INC(ulong, unsigned long, unsigned long);
ATOMIC_PROTO_INC(ptr, void *, void);

/*
 * These operations will be provided for userland, but may not be
 * implemented efficiently.
 */
uint16_t	atomic_cas_16(volatile uint16_t *, uint16_t, uint16_t);
uint8_t 	atomic_cas_8(volatile uint8_t *, uint8_t, uint8_t);

/*
 * Memory barrier operations
 */
void		membar_acquire(void);
void		membar_release(void);
void		membar_producer(void);
void		membar_consumer(void);
void		membar_sync(void);

/*
 * Deprecated memory barriers
 */
void		membar_enter(void);
void		membar_exit(void);

#ifdef	__HAVE_MEMBAR_DATADEP_CONSUMER
void		membar_datadep_consumer(void);
#else
#define	membar_datadep_consumer()	((void)0)
#endif

__END_DECLS

#if defined(KASAN)
#define atomic_add_32		kasan_atomic_add_32
#define atomic_add_int		kasan_atomic_add_int
#define atomic_add_long		kasan_atomic_add_long
#define atomic_add_ptr		kasan_atomic_add_ptr
#define atomic_add_64		kasan_atomic_add_64
#define atomic_add_32_nv	kasan_atomic_add_32_nv
#define atomic_add_int_nv	kasan_atomic_add_int_nv
#define atomic_add_long_nv	kasan_atomic_add_long_nv
#define atomic_add_ptr_nv	kasan_atomic_add_ptr_nv
#define atomic_add_64_nv	kasan_atomic_add_64_nv
#define atomic_and_32		kasan_atomic_and_32
#define atomic_and_uint		kasan_atomic_and_uint
#define atomic_and_ulong	kasan_atomic_and_ulong
#define atomic_and_64		kasan_atomic_and_64
#define atomic_and_32_nv	kasan_atomic_and_32_nv
#define atomic_and_uint_nv	kasan_atomic_and_uint_nv
#define atomic_and_ulong_nv	kasan_atomic_and_ulong_nv
#define atomic_and_64_nv	kasan_atomic_and_64_nv
#define atomic_or_32		kasan_atomic_or_32
#define atomic_or_uint		kasan_atomic_or_uint
#define atomic_or_ulong		kasan_atomic_or_ulong
#define atomic_or_64		kasan_atomic_or_64
#define atomic_or_32_nv		kasan_atomic_or_32_nv
#define atomic_or_uint_nv	kasan_atomic_or_uint_nv
#define atomic_or_ulong_nv	kasan_atomic_or_ulong_nv
#define atomic_or_64_nv		kasan_atomic_or_64_nv
#define atomic_cas_32		kasan_atomic_cas_32
#define atomic_cas_uint		kasan_atomic_cas_uint
#define atomic_cas_ulong	kasan_atomic_cas_ulong
#define atomic_cas_ptr		kasan_atomic_cas_ptr
#define atomic_cas_64		kasan_atomic_cas_64
#define atomic_cas_32_ni	kasan_atomic_cas_32_ni
#define atomic_cas_uint_ni	kasan_atomic_cas_uint_ni
#define atomic_cas_ulong_ni	kasan_atomic_cas_ulong_ni
#define atomic_cas_ptr_ni	kasan_atomic_cas_ptr_ni
#define atomic_cas_64_ni	kasan_atomic_cas_64_ni
#define atomic_swap_32		kasan_atomic_swap_32
#define atomic_swap_uint	kasan_atomic_swap_uint
#define atomic_swap_ulong	kasan_atomic_swap_ulong
#define atomic_swap_ptr		kasan_atomic_swap_ptr
#define atomic_swap_64		kasan_atomic_swap_64
#define atomic_dec_32		kasan_atomic_dec_32
#define atomic_dec_uint		kasan_atomic_dec_uint
#define atomic_dec_ulong	kasan_atomic_dec_ulong
#define atomic_dec_ptr		kasan_atomic_dec_ptr
#define atomic_dec_64		kasan_atomic_dec_64
#define atomic_dec_32_nv	kasan_atomic_dec_32_nv
#define atomic_dec_uint_nv	kasan_atomic_dec_uint_nv
#define atomic_dec_ulong_nv	kasan_atomic_dec_ulong_nv
#define atomic_dec_ptr_nv	kasan_atomic_dec_ptr_nv
#define atomic_dec_64_nv	kasan_atomic_dec_64_nv
#define atomic_inc_32		kasan_atomic_inc_32
#define atomic_inc_uint		kasan_atomic_inc_uint
#define atomic_inc_ulong	kasan_atomic_inc_ulong
#define atomic_inc_ptr		kasan_atomic_inc_ptr
#define atomic_inc_64		kasan_atomic_inc_64
#define atomic_inc_32_nv	kasan_atomic_inc_32_nv
#define atomic_inc_uint_nv	kasan_atomic_inc_uint_nv
#define atomic_inc_ulong_nv	kasan_atomic_inc_ulong_nv
#define atomic_inc_ptr_nv	kasan_atomic_inc_ptr_nv
#define atomic_inc_64_nv	kasan_atomic_inc_64_nv
#elif defined(KCSAN)
#define atomic_add_32		kcsan_atomic_add_32
#define atomic_add_int		kcsan_atomic_add_int
#define atomic_add_long		kcsan_atomic_add_long
#define atomic_add_ptr		kcsan_atomic_add_ptr
#define atomic_add_64		kcsan_atomic_add_64
#define atomic_add_32_nv	kcsan_atomic_add_32_nv
#define atomic_add_int_nv	kcsan_atomic_add_int_nv
#define atomic_add_long_nv	kcsan_atomic_add_long_nv
#define atomic_add_ptr_nv	kcsan_atomic_add_ptr_nv
#define atomic_add_64_nv	kcsan_atomic_add_64_nv
#define atomic_and_32		kcsan_atomic_and_32
#define atomic_and_uint		kcsan_atomic_and_uint
#define atomic_and_ulong	kcsan_atomic_and_ulong
#define atomic_and_64		kcsan_atomic_and_64
#define atomic_and_32_nv	kcsan_atomic_and_32_nv
#define atomic_and_uint_nv	kcsan_atomic_and_uint_nv
#define atomic_and_ulong_nv	kcsan_atomic_and_ulong_nv
#define atomic_and_64_nv	kcsan_atomic_and_64_nv
#define atomic_or_32		kcsan_atomic_or_32
#define atomic_or_uint		kcsan_atomic_or_uint
#define atomic_or_ulong		kcsan_atomic_or_ulong
#define atomic_or_64		kcsan_atomic_or_64
#define atomic_or_32_nv		kcsan_atomic_or_32_nv
#define atomic_or_uint_nv	kcsan_atomic_or_uint_nv
#define atomic_or_ulong_nv	kcsan_atomic_or_ulong_nv
#define atomic_or_64_nv		kcsan_atomic_or_64_nv
#define atomic_cas_32		kcsan_atomic_cas_32
#define atomic_cas_uint		kcsan_atomic_cas_uint
#define atomic_cas_ulong	kcsan_atomic_cas_ulong
#define atomic_cas_ptr		kcsan_atomic_cas_ptr
#define atomic_cas_64		kcsan_atomic_cas_64
#define atomic_cas_32_ni	kcsan_atomic_cas_32_ni
#define atomic_cas_uint_ni	kcsan_atomic_cas_uint_ni
#define atomic_cas_ulong_ni	kcsan_atomic_cas_ulong_ni
#define atomic_cas_ptr_ni	kcsan_atomic_cas_ptr_ni
#define atomic_cas_64_ni	kcsan_atomic_cas_64_ni
#define atomic_swap_32		kcsan_atomic_swap_32
#define atomic_swap_uint	kcsan_atomic_swap_uint
#define atomic_swap_ulong	kcsan_atomic_swap_ulong
#define atomic_swap_ptr		kcsan_atomic_swap_ptr
#define atomic_swap_64		kcsan_atomic_swap_64
#define atomic_dec_32		kcsan_atomic_dec_32
#define atomic_dec_uint		kcsan_atomic_dec_uint
#define atomic_dec_ulong	kcsan_atomic_dec_ulong
#define atomic_dec_ptr		kcsan_atomic_dec_ptr
#define atomic_dec_64		kcsan_atomic_dec_64
#define atomic_dec_32_nv	kcsan_atomic_dec_32_nv
#define atomic_dec_uint_nv	kcsan_atomic_dec_uint_nv
#define atomic_dec_ulong_nv	kcsan_atomic_dec_ulong_nv
#define atomic_dec_ptr_nv	kcsan_atomic_dec_ptr_nv
#define atomic_dec_64_nv	kcsan_atomic_dec_64_nv
#define atomic_inc_32		kcsan_atomic_inc_32
#define atomic_inc_uint		kcsan_atomic_inc_uint
#define atomic_inc_ulong	kcsan_atomic_inc_ulong
#define atomic_inc_ptr		kcsan_atomic_inc_ptr
#define atomic_inc_64		kcsan_atomic_inc_64
#define atomic_inc_32_nv	kcsan_atomic_inc_32_nv
#define atomic_inc_uint_nv	kcsan_atomic_inc_uint_nv
#define atomic_inc_ulong_nv	kcsan_atomic_inc_ulong_nv
#define atomic_inc_ptr_nv	kcsan_atomic_inc_ptr_nv
#define atomic_inc_64_nv	kcsan_atomic_inc_64_nv
#elif defined(KMSAN)
#define atomic_add_32		kmsan_atomic_add_32
#define atomic_add_int		kmsan_atomic_add_int
#define atomic_add_long		kmsan_atomic_add_long
#define atomic_add_ptr		kmsan_atomic_add_ptr
#define atomic_add_64		kmsan_atomic_add_64
#define atomic_add_32_nv	kmsan_atomic_add_32_nv
#define atomic_add_int_nv	kmsan_atomic_add_int_nv
#define atomic_add_long_nv	kmsan_atomic_add_long_nv
#define atomic_add_ptr_nv	kmsan_atomic_add_ptr_nv
#define atomic_add_64_nv	kmsan_atomic_add_64_nv
#define atomic_and_32		kmsan_atomic_and_32
#define atomic_and_uint		kmsan_atomic_and_uint
#define atomic_and_ulong	kmsan_atomic_and_ulong
#define atomic_and_64		kmsan_atomic_and_64
#define atomic_and_32_nv	kmsan_atomic_and_32_nv
#define atomic_and_uint_nv	kmsan_atomic_and_uint_nv
#define atomic_and_ulong_nv	kmsan_atomic_and_ulong_nv
#define atomic_and_64_nv	kmsan_atomic_and_64_nv
#define atomic_or_32		kmsan_atomic_or_32
#define atomic_or_uint		kmsan_atomic_or_uint
#define atomic_or_ulong		kmsan_atomic_or_ulong
#define atomic_or_64		kmsan_atomic_or_64
#define atomic_or_32_nv		kmsan_atomic_or_32_nv
#define atomic_or_uint_nv	kmsan_atomic_or_uint_nv
#define atomic_or_ulong_nv	kmsan_atomic_or_ulong_nv
#define atomic_or_64_nv		kmsan_atomic_or_64_nv
#define atomic_cas_32		kmsan_atomic_cas_32
#define atomic_cas_uint		kmsan_atomic_cas_uint
#define atomic_cas_ulong	kmsan_atomic_cas_ulong
#define atomic_cas_ptr		kmsan_atomic_cas_ptr
#define atomic_cas_64		kmsan_atomic_cas_64
#define atomic_cas_32_ni	kmsan_atomic_cas_32_ni
#define atomic_cas_uint_ni	kmsan_atomic_cas_uint_ni
#define atomic_cas_ulong_ni	kmsan_atomic_cas_ulong_ni
#define atomic_cas_ptr_ni	kmsan_atomic_cas_ptr_ni
#define atomic_cas_64_ni	kmsan_atomic_cas_64_ni
#define atomic_swap_32		kmsan_atomic_swap_32
#define atomic_swap_uint	kmsan_atomic_swap_uint
#define atomic_swap_ulong	kmsan_atomic_swap_ulong
#define atomic_swap_ptr		kmsan_atomic_swap_ptr
#define atomic_swap_64		kmsan_atomic_swap_64
#define atomic_dec_32		kmsan_atomic_dec_32
#define atomic_dec_uint		kmsan_atomic_dec_uint
#define atomic_dec_ulong	kmsan_atomic_dec_ulong
#define atomic_dec_ptr		kmsan_atomic_dec_ptr
#define atomic_dec_64		kmsan_atomic_dec_64
#define atomic_dec_32_nv	kmsan_atomic_dec_32_nv
#define atomic_dec_uint_nv	kmsan_atomic_dec_uint_nv
#define atomic_dec_ulong_nv	kmsan_atomic_dec_ulong_nv
#define atomic_dec_ptr_nv	kmsan_atomic_dec_ptr_nv
#define atomic_dec_64_nv	kmsan_atomic_dec_64_nv
#define atomic_inc_32		kmsan_atomic_inc_32
#define atomic_inc_uint		kmsan_atomic_inc_uint
#define atomic_inc_ulong	kmsan_atomic_inc_ulong
#define atomic_inc_ptr		kmsan_atomic_inc_ptr
#define atomic_inc_64		kmsan_atomic_inc_64
#define atomic_inc_32_nv	kmsan_atomic_inc_32_nv
#define atomic_inc_uint_nv	kmsan_atomic_inc_uint_nv
#define atomic_inc_ulong_nv	kmsan_atomic_inc_ulong_nv
#define atomic_inc_ptr_nv	kmsan_atomic_inc_ptr_nv
#define atomic_inc_64_nv	kmsan_atomic_inc_64_nv
#endif

#ifdef _KERNEL

#if 1 // XXX: __STDC_VERSION__ < 201112L

/* Pre-C11 definitions */

#include <sys/cdefs.h>

#include <lib/libkern/libkern.h>

#ifdef _LP64
#define	__HAVE_ATOMIC64_LOADSTORE	1
#define	__ATOMIC_SIZE_MAX		8
#else
#define	__ATOMIC_SIZE_MAX		4
#endif

/*
 * We assume that access to an aligned pointer to a volatile object of
 * at most __ATOMIC_SIZE_MAX bytes is guaranteed to be atomic.  This is
 * an assumption that may be wrong, but we hope it won't be wrong
 * before we just adopt the C11 atomic API.
 */
#define	__ATOMIC_PTR_CHECK(p) do					      \
{									      \
	CTASSERT(sizeof(*(p)) <= __ATOMIC_SIZE_MAX);			      \
	KASSERT(((uintptr_t)(p) & (sizeof(*(p)) - 1)) == 0);		      \
} while (0)

#ifdef KCSAN
void kcsan_atomic_load(const volatile void *, void *, int);
void kcsan_atomic_store(volatile void *, const void *, int);
#define __BEGIN_ATOMIC_LOAD(p, v) \
	union { __typeof__(*(p)) __al_val; char __al_buf[1]; } v; \
	kcsan_atomic_load(p, v.__al_buf, sizeof(v.__al_val))
#define __END_ATOMIC_LOAD(v) \
	(v).__al_val
#define __DO_ATOMIC_STORE(p, v) \
	kcsan_atomic_store(p, __UNVOLATILE(&v), sizeof(v))
#else
#define __BEGIN_ATOMIC_LOAD(p, v) \
	__typeof__(*(p)) v = *(p)
#define __END_ATOMIC_LOAD(v) \
	v
#ifdef __HAVE_HASHLOCKED_ATOMICS
#define __DO_ATOMIC_STORE(p, v)						      \
	__do_atomic_store(p, __UNVOLATILE(&v), sizeof(v))
#else  /* !__HAVE_HASHLOCKED_ATOMICS */
#define __DO_ATOMIC_STORE(p, v) \
	*p = v
#endif
#endif

#define	atomic_load_relaxed(p)						      \
({									      \
	const volatile __typeof__(*(p)) *__al_ptr = (p);		      \
	__ATOMIC_PTR_CHECK(__al_ptr);					      \
	__BEGIN_ATOMIC_LOAD(__al_ptr, __al_val);			      \
	__END_ATOMIC_LOAD(__al_val);					      \
})

#define	atomic_load_consume(p)						      \
({									      \
	const volatile __typeof__(*(p)) *__al_ptr = (p);		      \
	__ATOMIC_PTR_CHECK(__al_ptr);					      \
	__BEGIN_ATOMIC_LOAD(__al_ptr, __al_val);			      \
	membar_datadep_consumer();					      \
	__END_ATOMIC_LOAD(__al_val);					      \
})

#define	atomic_load_acquire(p)						      \
({									      \
	const volatile __typeof__(*(p)) *__al_ptr = (p);		      \
	__ATOMIC_PTR_CHECK(__al_ptr);					      \
	__BEGIN_ATOMIC_LOAD(__al_ptr, __al_val);			      \
	membar_acquire();						      \
	__END_ATOMIC_LOAD(__al_val);					      \
})

#define	atomic_store_relaxed(p,v)					      \
({									      \
	volatile __typeof__(*(p)) *__as_ptr = (p);			      \
	__typeof__(*(p)) __as_val = (v);				      \
	__ATOMIC_PTR_CHECK(__as_ptr);					      \
	__DO_ATOMIC_STORE(__as_ptr, __as_val);				      \
})

#define	atomic_store_release(p,v)					      \
({									      \
	volatile __typeof__(*(p)) *__as_ptr = (p);			      \
	__typeof__(*(p)) __as_val = (v);				      \
	__ATOMIC_PTR_CHECK(__as_ptr);					      \
	membar_release();						      \
	__DO_ATOMIC_STORE(__as_ptr, __as_val);				      \
})

#ifdef __HAVE_HASHLOCKED_ATOMICS
static __inline __always_inline void
__do_atomic_store(volatile void *p, const void *q, size_t size)
{
	switch (size) {
	case 1: {
		uint8_t v;
		unsigned s = 8 * ((uintptr_t)p & 3);
		uint32_t o, n, m = ~(0xffU << s);
		memcpy(&v, q, 1);
		do {
			o = atomic_load_relaxed((const volatile uint32_t *)p);
			n = (o & m) | ((uint32_t)v << s);
		} while (atomic_cas_32((volatile uint32_t *)p, o, n) != o);
		break;
	}
	case 2: {
		uint16_t v;
		unsigned s = 8 * (((uintptr_t)p & 2) >> 1);
		uint32_t o, n, m = ~(0xffffU << s);
		memcpy(&v, q, 2);
		do {
			o = atomic_load_relaxed((const volatile uint32_t *)p);
			n = (o & m) | ((uint32_t)v << s);
		} while (atomic_cas_32((volatile uint32_t *)p, o, n) != o);
		break;
	}
	case 4: {
		uint32_t v;
		memcpy(&v, q, 4);
		(void)atomic_swap_32(p, v);
		break;
	}
#ifdef __HAVE_ATOMIC64_LOADSTORE
	case 8: {
		uint64_t v;
		memcpy(&v, q, 8);
		(void)atomic_swap_64(p, v);
		break;
	}
#endif
	}
}
#endif	/* __HAVE_HASHLOCKED_ATOMICS */

#else  /* __STDC_VERSION__ >= 201112L */

/* C11 definitions, not yet available */

#include <stdatomic.h>

#define	atomic_load_relaxed(p)						      \
	atomic_load_explicit((p), memory_order_relaxed)
#if 0				/* memory_order_consume is not there yet */
#define	atomic_load_consume(p)						      \
	atomic_load_explicit((p), memory_order_consume)
#else
#define	atomic_load_consume(p)						      \
({									      \
	const __typeof__(*(p)) __al_val = atomic_load_relaxed(p);	      \
	membar_datadep_consumer();					      \
	__al_val;							      \
})
#endif
#define	atomic_load_acquire(p)						      \
	atomic_load_explicit((p), memory_order_acquire)
#define	atomic_store_relaxed(p, v)					      \
	atomic_store_explicit((p), (v), memory_order_relaxed)
#define	atomic_store_release(p, v)					      \
	atomic_store_explicit((p), (v), memory_order_release)

#endif	/* __STDC_VERSION__ */

#endif	/* _KERNEL */

#endif /* ! _SYS_ATOMIC_H_ */