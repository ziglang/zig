/*	$NetBSD: common_int_limits.h,v 1.1 2014/07/25 21:43:13 joerg Exp $	*/

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Joerg Sonnenberger.
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

#ifndef _SYS_COMMON_INT_LIMITS_H_
#define _SYS_COMMON_INT_LIMITS_H_

#ifndef __SIG_ATOMIC_MAX__
#error Your compiler does not provide limit macros.
#endif

/*
 * 7.18.2 Limits of specified-width integer types
 */

/* 7.18.2.1 Limits of exact-width integer types */

/* minimum values of exact-width signed integer types */
#define	INT8_MIN		(-__INT8_MAX__-1)
#define	INT16_MIN		(-__INT16_MAX__-1)
#define	INT32_MIN		(-__INT32_MAX__-1)
#define	INT64_MIN		(-__INT64_MAX__-1)

/* maximum values of exact-width signed integer types */
#define	INT8_MAX		__INT8_MAX__
#define	INT16_MAX		__INT16_MAX__
#define	INT32_MAX		__INT32_MAX__
#define	INT64_MAX		__INT64_MAX__

/* maximum values of exact-width unsigned integer types */
#define	UINT8_MAX		__UINT8_MAX__
#define	UINT16_MAX		__UINT16_MAX__
#define	UINT32_MAX		__UINT32_MAX__
#define	UINT64_MAX		__UINT64_MAX__

/* 7.18.2.2 Limits of minimum-width integer types */

/* minimum values of minimum-width signed integer types */
#define	INT_LEAST8_MIN		(-__INT_LEAST8_MAX__-1)
#define	INT_LEAST16_MIN		(-__INT_LEAST16_MAX__-1)
#define	INT_LEAST32_MIN		(-__INT_LEAST32_MAX__-1)
#define	INT_LEAST64_MIN		(-__INT_LEAST64_MAX__-1)

/* maximum values of minimum-width signed integer types */
#define	INT_LEAST8_MAX		__INT_LEAST8_MAX__
#define	INT_LEAST16_MAX		__INT_LEAST16_MAX__
#define	INT_LEAST32_MAX		__INT_LEAST32_MAX__
#define	INT_LEAST64_MAX		__INT_LEAST64_MAX__

/* maximum values of minimum-width unsigned integer types */
#define	UINT_LEAST8_MAX 	__UINT_LEAST8_MAX__
#define	UINT_LEAST16_MAX	__UINT_LEAST16_MAX__
#define	UINT_LEAST32_MAX	__UINT_LEAST32_MAX__
#define	UINT_LEAST64_MAX	__UINT_LEAST64_MAX__

/* 7.18.2.3 Limits of fastest minimum-width integer types */
 
/* minimum values of fastest minimum-width signed integer types */
#define	INT_FAST8_MIN		(-__INT_FAST8_MAX__-1)
#define	INT_FAST16_MIN		(-__INT_FAST16_MAX__-1)
#define	INT_FAST32_MIN		(-__INT_FAST32_MAX__-1)
#define	INT_FAST64_MIN		(-__INT_FAST64_MAX__-1)

/* maximum values of fastest minimum-width signed integer types */
#define	INT_FAST8_MAX		__INT_FAST8_MAX__
#define	INT_FAST16_MAX		__INT_FAST16_MAX__
#define	INT_FAST32_MAX		__INT_FAST32_MAX__
#define	INT_FAST64_MAX		__INT_FAST64_MAX__

/* maximum values of fastest minimum-width unsigned integer types */
#define	UINT_FAST8_MAX 	__UINT_FAST8_MAX__
#define	UINT_FAST16_MAX	__UINT_FAST16_MAX__
#define	UINT_FAST32_MAX	__UINT_FAST32_MAX__
#define	UINT_FAST64_MAX	__UINT_FAST64_MAX__

/* 7.18.2.4 Limits of integer types capable of holding object pointers */
#define	INTPTR_MIN	(-__INTPTR_MAX__-1)
#define	INTPTR_MAX	__INTPTR_MAX__
#define	UINTPTR_MAX	__UINTPTR_MAX__

/* 7.18.2.5 Limits of greatest-width integer types */

#define	INTMAX_MIN	(-__INTMAX_MAX__-1)
#define	INTMAX_MAX	__INTMAX_MAX__
#define	UINTMAX_MAX	__UINTMAX_MAX__


/*
 * 7.18.3 Limits of other integer types
 */

/* limits of ptrdiff_t */
#define	PTRDIFF_MIN	(-__PTRDIFF_MAX__-1)
#define	PTRDIFF_MAX	__PTRDIFF_MAX__

/* limits of sig_atomic_t */
#define	SIG_ATOMIC_MIN	(-__SIG_ATOMIC_MAX__-1)
#define	SIG_ATOMIC_MAX	__SIG_ATOMIC_MAX__

/* limit of size_t */
#define	SIZE_MAX	__SIZE_MAX__

#endif /* _SYS_COMMON_INT_LIMITS_H_ */