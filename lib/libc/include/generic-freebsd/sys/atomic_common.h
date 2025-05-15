/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2017 The FreeBSD Foundation
 *
 * This software was developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
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
#ifndef _SYS_ATOMIC_COMMON_H_
#define	_SYS_ATOMIC_COMMON_H_

#ifndef _MACHINE_ATOMIC_H_
#error do not include this header, use machine/atomic.h
#endif

#include <sys/types.h>

#define	__atomic_load_bool_relaxed(p)	(*(volatile _Bool *)(p))
#define	__atomic_store_bool_relaxed(p, v)	\
    (*(volatile _Bool *)(p) = (_Bool)(v))

#define	__atomic_load_char_relaxed(p)	(*(volatile u_char *)(p))
#define	__atomic_load_short_relaxed(p)	(*(volatile u_short *)(p))
#define	__atomic_load_int_relaxed(p)	(*(volatile u_int *)(p))
#define	__atomic_load_long_relaxed(p)	(*(volatile u_long *)(p))
#define	__atomic_load_8_relaxed(p)	(*(volatile uint8_t *)(p))
#define	__atomic_load_16_relaxed(p)	(*(volatile uint16_t *)(p))
#define	__atomic_load_32_relaxed(p)	(*(volatile uint32_t *)(p))
#define	__atomic_load_64_relaxed(p)	(*(volatile uint64_t *)(p))

#define	__atomic_store_char_relaxed(p, v)	\
    (*(volatile u_char *)(p) = (u_char)(v))
#define	__atomic_store_short_relaxed(p, v)	\
    (*(volatile u_short *)(p) = (u_short)(v))
#define	__atomic_store_int_relaxed(p, v)	\
    (*(volatile u_int *)(p) = (u_int)(v))
#define	__atomic_store_long_relaxed(p, v)	\
    (*(volatile u_long *)(p) = (u_long)(v))
#define	__atomic_store_8_relaxed(p, v)		\
    (*(volatile uint8_t *)(p) = (uint8_t)(v))
#define	__atomic_store_16_relaxed(p, v)		\
    (*(volatile uint16_t *)(p) = (uint16_t)(v))
#define	__atomic_store_32_relaxed(p, v)		\
    (*(volatile uint32_t *)(p) = (uint32_t)(v))
#define	__atomic_store_64_relaxed(p, v)		\
    (*(volatile uint64_t *)(p) = (uint64_t)(v))

/*
 * When _Generic is available, try to provide some type checking.
 */
#if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L) || \
    __has_extension(c_generic_selections)
#define	atomic_load_bool(p)			\
	_Generic(*(p), _Bool: __atomic_load_bool_relaxed(p))
#define	atomic_store_bool(p, v)			\
	_Generic(*(p), _Bool: __atomic_store_bool_relaxed(p, v))

#define	__atomic_load_generic(p, t, ut, n)	\
	_Generic(*(p),				\
	    t: __atomic_load_ ## n ## _relaxed(p), \
	    ut: __atomic_load_ ## n ## _relaxed(p))
#define	__atomic_store_generic(p, v, t, ut, n)	\
	_Generic(*(p),				\
	    t: __atomic_store_ ## n ## _relaxed(p, v), \
	    ut: __atomic_store_ ## n ## _relaxed(p, v))
#else
#define	atomic_load_bool(p)			\
	__atomic_load_bool_relaxed(p)
#define	atomic_store_bool(p, v)			\
	__atomic_store_bool_relaxed(p, v)
#define	__atomic_load_generic(p, t, ut, n)	\
	__atomic_load_ ## n ## _relaxed(p)
#define	__atomic_store_generic(p, v, t, ut, n)	\
	__atomic_store_ ## n ## _relaxed(p, v)
#endif

#define	atomic_load_char(p)	__atomic_load_generic(p, char, u_char, char)
#define	atomic_load_short(p)	__atomic_load_generic(p, short, u_short, short)
#define	atomic_load_int(p)	__atomic_load_generic(p, int, u_int, int)
#define	atomic_load_long(p)	__atomic_load_generic(p, long, u_long, long)
#define	atomic_load_8(p)	__atomic_load_generic(p, int8_t, uint8_t, 8)
#define	atomic_load_16(p)	__atomic_load_generic(p, int16_t, uint16_t, 16)
#define	atomic_load_32(p)	__atomic_load_generic(p, int32_t, uint32_t, 32)
#ifdef __LP64__
#define	atomic_load_64(p)	__atomic_load_generic(p, int64_t, uint64_t, 64)
#endif
#define	atomic_store_char(p, v)			\
	__atomic_store_generic(p, v, char, u_char, char)
#define	atomic_store_short(p, v)		\
	__atomic_store_generic(p, v, short, u_short, short)
#define	atomic_store_int(p, v)			\
	__atomic_store_generic(p, v, int, u_int, int)
#define	atomic_store_long(p, v)			\
	__atomic_store_generic(p, v, long, u_long, long)
#define	atomic_store_8(p, v)			\
	__atomic_store_generic(p, v, int8_t, uint8_t, 8)
#define	atomic_store_16(p, v)			\
	__atomic_store_generic(p, v, int16_t, uint16_t, 16)
#define	atomic_store_32(p, v)			\
	__atomic_store_generic(p, v, int32_t, uint32_t, 32)
#ifdef __LP64__
#define	atomic_store_64(p, v)			\
	__atomic_store_generic(p, v, int64_t, uint64_t, 64)
#endif

#define	atomic_load_ptr(p)	(*(volatile __typeof(*p) *)(p))
#define	atomic_store_ptr(p, v)	(*(volatile __typeof(*p) *)(p) = (v))

/*
 * Currently all architectures provide acquire and release fences on their own,
 * but they don't provide consume. Kludge below allows relevant code to stop
 * openly resorting to the stronger acquire fence, to be sorted out.
 */
#define	atomic_load_consume_ptr(p)	\
    ((__typeof(*p)) atomic_load_acq_ptr((uintptr_t *)p))

#define	atomic_interrupt_fence()	__compiler_membar()

#endif /* !_SYS_ATOMIC_COMMON_H_ */