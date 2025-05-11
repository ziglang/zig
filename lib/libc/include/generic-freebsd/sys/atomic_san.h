/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Andrew Turner
 * Copyright (c) 2021 The FreeBSD Foundation
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * Portions of this software were written by Mark Johnston under sponsorship
 * by the FreeBSD Foundation.
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

#ifndef _SYS_ATOMIC_SAN_H_
#define	_SYS_ATOMIC_SAN_H_

#ifndef _MACHINE_ATOMIC_H_
#error do not include this header, use machine/atomic.h
#endif

#include <sys/types.h>

#define	ATOMIC_SAN_FUNC_1(sp, op, name, type)				\
	void sp##_atomic_##op##_##name(volatile type *, type);		\
	void sp##_atomic_##op##_acq_##name(volatile type *, type);	\
	void sp##_atomic_##op##_rel_##name(volatile type *, type)

#define	ATOMIC_SAN_CMPSET(sp, name, type)				\
	int sp##_atomic_cmpset_##name(volatile type *, type, type);	\
	int sp##_atomic_cmpset_acq_##name(volatile type *, type, type); \
	int sp##_atomic_cmpset_rel_##name(volatile type *, type, type)

#define	ATOMIC_SAN_FCMPSET(sp, name, type)				\
	int sp##_atomic_fcmpset_##name(volatile type *, type *, type);	\
	int sp##_atomic_fcmpset_acq_##name(volatile type *, type *, type); \
	int sp##_atomic_fcmpset_rel_##name(volatile type *, type *, type)

#define	ATOMIC_SAN_READ(sp, op, name, type)				\
	type sp##_atomic_##op##_##name(volatile type *, type)

#define	ATOMIC_SAN_READANDCLEAR(sp, name, type)				\
	type sp##_atomic_readandclear_##name(volatile type *)

#define	ATOMIC_SAN_LOAD(sp, name, type)					\
	type sp##_atomic_load_##name(volatile type *)

#define	ATOMIC_SAN_LOAD_ACQ(sp, name, type)				\
	type sp##_atomic_load_acq_##name(volatile type *)

#define	ATOMIC_SAN_STORE(sp, name, type)				\
	void sp##_atomic_store_##name(volatile type *, type)

#define	ATOMIC_SAN_STORE_REL(sp, name, type)				\
	void sp##_atomic_store_rel_##name(volatile type *, type)

#define	ATOMIC_SAN_TEST(sp, op, name, type)				\
	int sp##_atomic_##op##_##name(volatile type *, u_int);		\
	int sp##_atomic_##op##_acq_##name(volatile type *, u_int)

#define	_ATOMIC_SAN_THREAD_FENCE(sp)					\
	void sp##_atomic_thread_fence_acq(void);			\
	void sp##_atomic_thread_fence_rel(void);			\
	void sp##_atomic_thread_fence_acq_rel(void);			\
	void sp##_atomic_thread_fence_seq_cst(void);			\
	void sp##_atomic_interrupt_fence(void)

#define	ATOMIC_SAN_THREAD_FENCE(sp)					\
	_ATOMIC_SAN_THREAD_FENCE(sp)

#define	ATOMIC_SAN_LOAD_STORE(sp, name, type)				\
	ATOMIC_SAN_LOAD(sp, name, type);				\
	ATOMIC_SAN_STORE(sp, name, type)

#define	_ATOMIC_SAN_FUNCS(sp, name, type)				\
	ATOMIC_SAN_FUNC_1(sp, add, name, type);				\
	ATOMIC_SAN_FUNC_1(sp, clear, name, type);			\
	ATOMIC_SAN_CMPSET(sp, name, type);				\
	ATOMIC_SAN_FCMPSET(sp, name, type);				\
	ATOMIC_SAN_READ(sp, fetchadd, name, type);			\
	ATOMIC_SAN_LOAD(sp, name, type);				\
	ATOMIC_SAN_LOAD_ACQ(sp, name, type);				\
	ATOMIC_SAN_READANDCLEAR(sp, name, type);			\
	ATOMIC_SAN_FUNC_1(sp, set, name, type);				\
	ATOMIC_SAN_FUNC_1(sp, subtract, name, type);			\
	ATOMIC_SAN_STORE(sp, name, type);				\
	ATOMIC_SAN_STORE_REL(sp, name, type);				\
	ATOMIC_SAN_READ(sp, swap, name, type);				\
	ATOMIC_SAN_TEST(sp, testandclear, name, type);			\
	ATOMIC_SAN_TEST(sp, testandset, name, type)

#define	ATOMIC_SAN_FUNCS(name, type)					\
	_ATOMIC_SAN_FUNCS(SAN_INTERCEPTOR_PREFIX, name, type)

ATOMIC_SAN_FUNCS(char, uint8_t);
ATOMIC_SAN_FUNCS(short, uint16_t);
ATOMIC_SAN_FUNCS(int, u_int);
ATOMIC_SAN_FUNCS(long, u_long);
ATOMIC_SAN_FUNCS(ptr, uintptr_t);
ATOMIC_SAN_FUNCS(8, uint8_t);
ATOMIC_SAN_FUNCS(16, uint16_t);
ATOMIC_SAN_FUNCS(32, uint32_t);
ATOMIC_SAN_FUNCS(64, uint64_t);
ATOMIC_SAN_LOAD_STORE(SAN_INTERCEPTOR_PREFIX, bool, bool);
ATOMIC_SAN_THREAD_FENCE(SAN_INTERCEPTOR_PREFIX);

#ifndef SAN_RUNTIME

/*
 * Redirect uses of an atomic(9) function to the sanitizer's interceptor.
 * For instance, KASAN callers of atomic_add_char() will be redirected to
 * kasan_atomic_add_char().
 */
#define	ATOMIC_SAN(func)						\
	__CONCAT(SAN_INTERCEPTOR_PREFIX, __CONCAT(_atomic_, func))

#define	atomic_load_bool		ATOMIC_SAN(load_bool)
#define	atomic_store_bool		ATOMIC_SAN(store_bool)

#define	atomic_add_char			ATOMIC_SAN(add_char)
#define	atomic_add_acq_char		ATOMIC_SAN(add_acq_char)
#define	atomic_add_rel_char		ATOMIC_SAN(add_rel_char)
#define	atomic_clear_char		ATOMIC_SAN(clear_char)
#define	atomic_clear_acq_char		ATOMIC_SAN(clear_acq_char)
#define	atomic_clear_rel_char		ATOMIC_SAN(clear_rel_char)
#define	atomic_cmpset_char		ATOMIC_SAN(cmpset_char)
#define	atomic_cmpset_acq_char		ATOMIC_SAN(cmpset_acq_char)
#define	atomic_cmpset_rel_char		ATOMIC_SAN(cmpset_rel_char)
#define	atomic_fcmpset_char		ATOMIC_SAN(fcmpset_char)
#define	atomic_fcmpset_acq_char		ATOMIC_SAN(fcmpset_acq_char)
#define	atomic_fcmpset_rel_char		ATOMIC_SAN(fcmpset_rel_char)
#define	atomic_fetchadd_char		ATOMIC_SAN(fetchadd_char)
#define	atomic_load_char		ATOMIC_SAN(load_char)
#define	atomic_load_acq_char		ATOMIC_SAN(load_acq_char)
#define	atomic_readandclear_char	ATOMIC_SAN(readandclear_char)
#define	atomic_set_char			ATOMIC_SAN(set_char)
#define	atomic_set_acq_char		ATOMIC_SAN(set_acq_char)
#define	atomic_set_rel_char		ATOMIC_SAN(set_rel_char)
#define	atomic_subtract_char		ATOMIC_SAN(subtract_char)
#define	atomic_subtract_acq_char	ATOMIC_SAN(subtract_acq_char)
#define	atomic_subtract_rel_char	ATOMIC_SAN(subtract_rel_char)
#define	atomic_store_char		ATOMIC_SAN(store_char)
#define	atomic_store_rel_char		ATOMIC_SAN(store_rel_char)
#define	atomic_swap_char		ATOMIC_SAN(swap_char)
#define	atomic_testandclear_char	ATOMIC_SAN(testandclear_char)
#define	atomic_testandset_char		ATOMIC_SAN(testandset_char)

#define	atomic_add_short		ATOMIC_SAN(add_short)
#define	atomic_add_acq_short		ATOMIC_SAN(add_acq_short)
#define	atomic_add_rel_short		ATOMIC_SAN(add_rel_short)
#define	atomic_clear_short		ATOMIC_SAN(clear_short)
#define	atomic_clear_acq_short		ATOMIC_SAN(clear_acq_short)
#define	atomic_clear_rel_short		ATOMIC_SAN(clear_rel_short)
#define	atomic_cmpset_short		ATOMIC_SAN(cmpset_short)
#define	atomic_cmpset_acq_short		ATOMIC_SAN(cmpset_acq_short)
#define	atomic_cmpset_rel_short		ATOMIC_SAN(cmpset_rel_short)
#define	atomic_fcmpset_short		ATOMIC_SAN(fcmpset_short)
#define	atomic_fcmpset_acq_short	ATOMIC_SAN(fcmpset_acq_short)
#define	atomic_fcmpset_rel_short	ATOMIC_SAN(fcmpset_rel_short)
#define	atomic_fetchadd_short		ATOMIC_SAN(fetchadd_short)
#define	atomic_load_short		ATOMIC_SAN(load_short)
#define	atomic_load_acq_short		ATOMIC_SAN(load_acq_short)
#define	atomic_readandclear_short	ATOMIC_SAN(readandclear_short)
#define	atomic_set_short		ATOMIC_SAN(set_short)
#define	atomic_set_acq_short		ATOMIC_SAN(set_acq_short)
#define	atomic_set_rel_short		ATOMIC_SAN(set_rel_short)
#define	atomic_subtract_short		ATOMIC_SAN(subtract_short)
#define	atomic_subtract_acq_short	ATOMIC_SAN(subtract_acq_short)
#define	atomic_subtract_rel_short	ATOMIC_SAN(subtract_rel_short)
#define	atomic_store_short		ATOMIC_SAN(store_short)
#define	atomic_store_rel_short		ATOMIC_SAN(store_rel_short)
#define	atomic_swap_short		ATOMIC_SAN(swap_short)
#define	atomic_testandclear_short	ATOMIC_SAN(testandclear_short)
#define	atomic_testandset_short		ATOMIC_SAN(testandset_short)

#define	atomic_add_int			ATOMIC_SAN(add_int)
#define	atomic_add_acq_int		ATOMIC_SAN(add_acq_int)
#define	atomic_add_rel_int		ATOMIC_SAN(add_rel_int)
#define	atomic_clear_int		ATOMIC_SAN(clear_int)
#define	atomic_clear_acq_int		ATOMIC_SAN(clear_acq_int)
#define	atomic_clear_rel_int		ATOMIC_SAN(clear_rel_int)
#define	atomic_cmpset_int		ATOMIC_SAN(cmpset_int)
#define	atomic_cmpset_acq_int		ATOMIC_SAN(cmpset_acq_int)
#define	atomic_cmpset_rel_int		ATOMIC_SAN(cmpset_rel_int)
#define	atomic_fcmpset_int		ATOMIC_SAN(fcmpset_int)
#define	atomic_fcmpset_acq_int		ATOMIC_SAN(fcmpset_acq_int)
#define	atomic_fcmpset_rel_int		ATOMIC_SAN(fcmpset_rel_int)
#define	atomic_fetchadd_int		ATOMIC_SAN(fetchadd_int)
#define	atomic_load_int			ATOMIC_SAN(load_int)
#define	atomic_load_acq_int		ATOMIC_SAN(load_acq_int)
#define	atomic_readandclear_int		ATOMIC_SAN(readandclear_int)
#define	atomic_set_int			ATOMIC_SAN(set_int)
#define	atomic_set_acq_int		ATOMIC_SAN(set_acq_int)
#define	atomic_set_rel_int		ATOMIC_SAN(set_rel_int)
#define	atomic_subtract_int		ATOMIC_SAN(subtract_int)
#define	atomic_subtract_acq_int		ATOMIC_SAN(subtract_acq_int)
#define	atomic_subtract_rel_int		ATOMIC_SAN(subtract_rel_int)
#define	atomic_store_int		ATOMIC_SAN(store_int)
#define	atomic_store_rel_int		ATOMIC_SAN(store_rel_int)
#define	atomic_swap_int			ATOMIC_SAN(swap_int)
#define	atomic_testandclear_int		ATOMIC_SAN(testandclear_int)
#define	atomic_testandset_int		ATOMIC_SAN(testandset_int)

#define	atomic_add_long			ATOMIC_SAN(add_long)
#define	atomic_add_acq_long		ATOMIC_SAN(add_acq_long)
#define	atomic_add_rel_long		ATOMIC_SAN(add_rel_long)
#define	atomic_clear_long		ATOMIC_SAN(clear_long)
#define	atomic_clear_acq_long		ATOMIC_SAN(clear_acq_long)
#define	atomic_clear_rel_long		ATOMIC_SAN(clear_rel_long)
#define	atomic_cmpset_long		ATOMIC_SAN(cmpset_long)
#define	atomic_cmpset_acq_long		ATOMIC_SAN(cmpset_acq_long)
#define	atomic_cmpset_rel_long		ATOMIC_SAN(cmpset_rel_long)
#define	atomic_fcmpset_long		ATOMIC_SAN(fcmpset_long)
#define	atomic_fcmpset_acq_long		ATOMIC_SAN(fcmpset_acq_long)
#define	atomic_fcmpset_rel_long		ATOMIC_SAN(fcmpset_rel_long)
#define	atomic_fetchadd_long		ATOMIC_SAN(fetchadd_long)
#define	atomic_load_long		ATOMIC_SAN(load_long)
#define	atomic_load_acq_long		ATOMIC_SAN(load_acq_long)
#define	atomic_readandclear_long	ATOMIC_SAN(readandclear_long)
#define	atomic_set_long			ATOMIC_SAN(set_long)
#define	atomic_set_acq_long		ATOMIC_SAN(set_acq_long)
#define	atomic_set_rel_long		ATOMIC_SAN(set_rel_long)
#define	atomic_subtract_long		ATOMIC_SAN(subtract_long)
#define	atomic_subtract_acq_long	ATOMIC_SAN(subtract_acq_long)
#define	atomic_subtract_rel_long	ATOMIC_SAN(subtract_rel_long)
#define	atomic_store_long		ATOMIC_SAN(store_long)
#define	atomic_store_rel_long		ATOMIC_SAN(store_rel_long)
#define	atomic_swap_long		ATOMIC_SAN(swap_long)
#define	atomic_testandclear_long	ATOMIC_SAN(testandclear_long)
#define	atomic_testandset_long		ATOMIC_SAN(testandset_long)
#define	atomic_testandset_acq_long	ATOMIC_SAN(testandset_acq_long)

#define	atomic_add_ptr			ATOMIC_SAN(add_ptr)
#define	atomic_add_acq_ptr		ATOMIC_SAN(add_acq_ptr)
#define	atomic_add_rel_ptr		ATOMIC_SAN(add_rel_ptr)
#define	atomic_clear_ptr		ATOMIC_SAN(clear_ptr)
#define	atomic_clear_acq_ptr		ATOMIC_SAN(clear_acq_ptr)
#define	atomic_clear_rel_ptr		ATOMIC_SAN(clear_rel_ptr)
#define	atomic_cmpset_ptr		ATOMIC_SAN(cmpset_ptr)
#define	atomic_cmpset_acq_ptr		ATOMIC_SAN(cmpset_acq_ptr)
#define	atomic_cmpset_rel_ptr		ATOMIC_SAN(cmpset_rel_ptr)
#define	atomic_fcmpset_ptr		ATOMIC_SAN(fcmpset_ptr)
#define	atomic_fcmpset_acq_ptr		ATOMIC_SAN(fcmpset_acq_ptr)
#define	atomic_fcmpset_rel_ptr		ATOMIC_SAN(fcmpset_rel_ptr)
#define	atomic_fetchadd_ptr		ATOMIC_SAN(fetchadd_ptr)
#define	atomic_load_ptr(x)						\
	((__typeof(*x))ATOMIC_SAN(load_ptr)(				\
	    __DECONST(volatile uintptr_t *, (x))))
#define	atomic_load_acq_ptr		ATOMIC_SAN(load_acq_ptr)
#define	atomic_load_consume_ptr(x)					\
	((__typeof(*x))atomic_load_acq_ptr((volatile uintptr_t *)(x)))
#define	atomic_readandclear_ptr		ATOMIC_SAN(readandclear_ptr)
#define	atomic_set_ptr			ATOMIC_SAN(set_ptr)
#define	atomic_set_acq_ptr		ATOMIC_SAN(set_acq_ptr)
#define	atomic_set_rel_ptr		ATOMIC_SAN(set_rel_ptr)
#define	atomic_subtract_ptr		ATOMIC_SAN(subtract_ptr)
#define	atomic_subtract_acq_ptr		ATOMIC_SAN(subtract_acq_ptr)
#define	atomic_subtract_rel_ptr		ATOMIC_SAN(subtract_rel_ptr)
#define	atomic_store_ptr(x, v)		({					\
	__typeof(*x) __value = (v);						\
	ATOMIC_SAN(store_ptr)((volatile uintptr_t *)(x), (uintptr_t)(__value));\
})
#define	atomic_store_rel_ptr		ATOMIC_SAN(store_rel_ptr)
#define	atomic_swap_ptr			ATOMIC_SAN(swap_ptr)
#define	atomic_testandclear_ptr		ATOMIC_SAN(testandclear_ptr)
#define	atomic_testandset_ptr		ATOMIC_SAN(testandset_ptr)

#define	atomic_add_8			ATOMIC_SAN(add_8)
#define	atomic_add_acq_8		ATOMIC_SAN(add_acq_8)
#define	atomic_add_rel_8		ATOMIC_SAN(add_rel_8)
#define	atomic_clear_8			ATOMIC_SAN(clear_8)
#define	atomic_clear_acq_8		ATOMIC_SAN(clear_acq_8)
#define	atomic_clear_rel_8		ATOMIC_SAN(clear_rel_8)
#define	atomic_cmpset_8			ATOMIC_SAN(cmpset_8)
#define	atomic_cmpset_acq_8		ATOMIC_SAN(cmpset_acq_8)
#define	atomic_cmpset_rel_8		ATOMIC_SAN(cmpset_rel_8)
#define	atomic_fcmpset_8		ATOMIC_SAN(fcmpset_8)
#define	atomic_fcmpset_acq_8		ATOMIC_SAN(fcmpset_acq_8)
#define	atomic_fcmpset_rel_8		ATOMIC_SAN(fcmpset_rel_8)
#define	atomic_fetchadd_8		ATOMIC_SAN(fetchadd_8)
#define	atomic_load_8			ATOMIC_SAN(load_8)
#define	atomic_load_acq_8		ATOMIC_SAN(load_acq_8)
#define	atomic_readandclear_8		ATOMIC_SAN(readandclear_8)
#define	atomic_set_8			ATOMIC_SAN(set_8)
#define	atomic_set_acq_8		ATOMIC_SAN(set_acq_8)
#define	atomic_set_rel_8		ATOMIC_SAN(set_rel_8)
#define	atomic_subtract_8		ATOMIC_SAN(subtract_8)
#define	atomic_subtract_acq_8		ATOMIC_SAN(subtract_acq_8)
#define	atomic_subtract_rel_8		ATOMIC_SAN(subtract_rel_8)
#define	atomic_store_8			ATOMIC_SAN(store_8)
#define	atomic_store_rel_8		ATOMIC_SAN(store_rel_8)
#define	atomic_swap_8			ATOMIC_SAN(swap_8)
#define	atomic_testandclear_8		ATOMIC_SAN(testandclear_8)
#define	atomic_testandset_8		ATOMIC_SAN(testandset_8)

#define	atomic_add_16			ATOMIC_SAN(add_16)
#define	atomic_add_acq_16		ATOMIC_SAN(add_acq_16)
#define	atomic_add_rel_16		ATOMIC_SAN(add_rel_16)
#define	atomic_clear_16			ATOMIC_SAN(clear_16)
#define	atomic_clear_acq_16		ATOMIC_SAN(clear_acq_16)
#define	atomic_clear_rel_16		ATOMIC_SAN(clear_rel_16)
#define	atomic_cmpset_16		ATOMIC_SAN(cmpset_16)
#define	atomic_cmpset_acq_16		ATOMIC_SAN(cmpset_acq_16)
#define	atomic_cmpset_rel_16		ATOMIC_SAN(cmpset_rel_16)
#define	atomic_fcmpset_16		ATOMIC_SAN(fcmpset_16)
#define	atomic_fcmpset_acq_16		ATOMIC_SAN(fcmpset_acq_16)
#define	atomic_fcmpset_rel_16		ATOMIC_SAN(fcmpset_rel_16)
#define	atomic_fetchadd_16		ATOMIC_SAN(fetchadd_16)
#define	atomic_load_16			ATOMIC_SAN(load_16)
#define	atomic_load_acq_16		ATOMIC_SAN(load_acq_16)
#define	atomic_readandclear_16		ATOMIC_SAN(readandclear_16)
#define	atomic_set_16			ATOMIC_SAN(set_16)
#define	atomic_set_acq_16		ATOMIC_SAN(set_acq_16)
#define	atomic_set_rel_16		ATOMIC_SAN(set_rel_16)
#define	atomic_subtract_16		ATOMIC_SAN(subtract_16)
#define	atomic_subtract_acq_16		ATOMIC_SAN(subtract_acq_16)
#define	atomic_subtract_rel_16		ATOMIC_SAN(subtract_rel_16)
#define	atomic_store_16			ATOMIC_SAN(store_16)
#define	atomic_store_rel_16		ATOMIC_SAN(store_rel_16)
#define	atomic_swap_16			ATOMIC_SAN(swap_16)
#define	atomic_testandclear_16		ATOMIC_SAN(testandclear_16)
#define	atomic_testandset_16		ATOMIC_SAN(testandset_16)

#define	atomic_add_32			ATOMIC_SAN(add_32)
#define	atomic_add_acq_32		ATOMIC_SAN(add_acq_32)
#define	atomic_add_rel_32		ATOMIC_SAN(add_rel_32)
#define	atomic_clear_32			ATOMIC_SAN(clear_32)
#define	atomic_clear_acq_32		ATOMIC_SAN(clear_acq_32)
#define	atomic_clear_rel_32		ATOMIC_SAN(clear_rel_32)
#define	atomic_cmpset_32		ATOMIC_SAN(cmpset_32)
#define	atomic_cmpset_acq_32		ATOMIC_SAN(cmpset_acq_32)
#define	atomic_cmpset_rel_32		ATOMIC_SAN(cmpset_rel_32)
#define	atomic_fcmpset_32		ATOMIC_SAN(fcmpset_32)
#define	atomic_fcmpset_acq_32		ATOMIC_SAN(fcmpset_acq_32)
#define	atomic_fcmpset_rel_32		ATOMIC_SAN(fcmpset_rel_32)
#define	atomic_fetchadd_32		ATOMIC_SAN(fetchadd_32)
#define	atomic_load_32			ATOMIC_SAN(load_32)
#define	atomic_load_acq_32		ATOMIC_SAN(load_acq_32)
#define	atomic_readandclear_32		ATOMIC_SAN(readandclear_32)
#define	atomic_set_32			ATOMIC_SAN(set_32)
#define	atomic_set_acq_32		ATOMIC_SAN(set_acq_32)
#define	atomic_set_rel_32		ATOMIC_SAN(set_rel_32)
#define	atomic_subtract_32		ATOMIC_SAN(subtract_32)
#define	atomic_subtract_acq_32		ATOMIC_SAN(subtract_acq_32)
#define	atomic_subtract_rel_32		ATOMIC_SAN(subtract_rel_32)
#define	atomic_store_32			ATOMIC_SAN(store_32)
#define	atomic_store_rel_32		ATOMIC_SAN(store_rel_32)
#define	atomic_swap_32			ATOMIC_SAN(swap_32)
#define	atomic_testandclear_32		ATOMIC_SAN(testandclear_32)
#define	atomic_testandset_32		ATOMIC_SAN(testandset_32)

#define	atomic_add_64			ATOMIC_SAN(add_64)
#define	atomic_add_acq_64		ATOMIC_SAN(add_acq_64)
#define	atomic_add_rel_64		ATOMIC_SAN(add_rel_64)
#define	atomic_clear_64			ATOMIC_SAN(clear_64)
#define	atomic_clear_acq_64		ATOMIC_SAN(clear_acq_64)
#define	atomic_clear_rel_64		ATOMIC_SAN(clear_rel_64)
#define	atomic_cmpset_64		ATOMIC_SAN(cmpset_64)
#define	atomic_cmpset_acq_64		ATOMIC_SAN(cmpset_acq_64)
#define	atomic_cmpset_rel_64		ATOMIC_SAN(cmpset_rel_64)
#define	atomic_fcmpset_64		ATOMIC_SAN(fcmpset_64)
#define	atomic_fcmpset_acq_64		ATOMIC_SAN(fcmpset_acq_64)
#define	atomic_fcmpset_rel_64		ATOMIC_SAN(fcmpset_rel_64)
#define	atomic_fetchadd_64		ATOMIC_SAN(fetchadd_64)
#define	atomic_load_64			ATOMIC_SAN(load_64)
#define	atomic_load_acq_64		ATOMIC_SAN(load_acq_64)
#define	atomic_readandclear_64		ATOMIC_SAN(readandclear_64)
#define	atomic_set_64			ATOMIC_SAN(set_64)
#define	atomic_set_acq_64		ATOMIC_SAN(set_acq_64)
#define	atomic_set_rel_64		ATOMIC_SAN(set_rel_64)
#define	atomic_subtract_64		ATOMIC_SAN(subtract_64)
#define	atomic_subtract_acq_64		ATOMIC_SAN(subtract_acq_64)
#define	atomic_subtract_rel_64		ATOMIC_SAN(subtract_rel_64)
#define	atomic_store_64			ATOMIC_SAN(store_64)
#define	atomic_store_rel_64		ATOMIC_SAN(store_rel_64)
#define	atomic_swap_64			ATOMIC_SAN(swap_64)
#define	atomic_testandclear_64		ATOMIC_SAN(testandclear_64)
#define	atomic_testandset_64		ATOMIC_SAN(testandset_64)

#define	atomic_thread_fence_acq		ATOMIC_SAN(thread_fence_acq)
#define	atomic_thread_fence_acq_rel	ATOMIC_SAN(thread_fence_acq_rel)
#define	atomic_thread_fence_rel		ATOMIC_SAN(thread_fence_rel)
#define	atomic_thread_fence_seq_cst	ATOMIC_SAN(thread_fence_seq_cst)
#define	atomic_interrupt_fence		ATOMIC_SAN(interrupt_fence)

#endif /* !SAN_RUNTIME */

#endif /* !_SYS_ATOMIC_SAN_H_ */