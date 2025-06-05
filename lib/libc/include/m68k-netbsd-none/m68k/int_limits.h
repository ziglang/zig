/*	$NetBSD: int_limits.h,v 1.8 2014/08/13 22:31:07 matt Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
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

#ifndef _M68K_INT_LIMITS_H_
#define _M68K_INT_LIMITS_H_

#ifdef __SIG_ATOMIC_MAX__
#include <sys/common_int_limits.h>
#else
/*
 * 7.18.2 Limits of specified-width integer types
 */

/* 7.18.2.1 Limits of exact-width integer types */

/* minimum values of exact-width signed integer types */
#define	INT8_MIN	(-0x7f-1)			/* int8_t	  */
#define	INT16_MIN	(-0x7fff-1)			/* int16_t	  */
#define	INT32_MIN	(-0x7fffffff-1)			/* int32_t	  */
#define	INT64_MIN	(-0x7fffffffffffffffLL-1)	/* int64_t	  */

/* maximum values of exact-width signed integer types */
#define	INT8_MAX	0x7f				/* int8_t	  */
#define	INT16_MAX	0x7fff				/* int16_t	  */
#define	INT32_MAX	0x7fffffff			/* int32_t	  */
#define	INT64_MAX	0x7fffffffffffffffLL		/* int64_t	  */

/* maximum values of exact-width unsigned integer types */
#define	UINT8_MAX	0xff				/* uint8_t	  */
#define	UINT16_MAX	0xffff				/* uint16_t	  */
#define	UINT32_MAX	0xffffffffU			/* uint32_t	  */
#define	UINT64_MAX	0xffffffffffffffffULL		/* uint64_t	  */

/* 7.18.2.2 Limits of minimum-width integer types */

/* minimum values of minimum-width signed integer types */
#define	INT_LEAST8_MIN	(-0x7f-1)			/* int_least8_t	  */
#define	INT_LEAST16_MIN	(-0x7fff-1)			/* int_least16_t  */
#define	INT_LEAST32_MIN	(-0x7fffffff-1)			/* int_least32_t  */
#define	INT_LEAST64_MIN	(-0x7fffffffffffffffLL-1)	/* int_least64_t  */

/* maximum values of minimum-width signed integer types */
#define	INT_LEAST8_MAX	0x7f				/* int_least8_t	  */
#define	INT_LEAST16_MAX	0x7fff				/* int_least16_t  */
#define	INT_LEAST32_MAX	0x7fffffff			/* int_least32_t  */
#define	INT_LEAST64_MAX	0x7fffffffffffffffLL		/* int_least64_t  */

/* maximum values of minimum-width unsigned integer types */
#define	UINT_LEAST8_MAX	 0xff				/* uint_least8_t  */
#define	UINT_LEAST16_MAX 0xffff				/* uint_least16_t */
#define	UINT_LEAST32_MAX 0xffffffffU			/* uint_least32_t */
#define	UINT_LEAST64_MAX 0xffffffffffffffffULL		/* uint_least64_t */

/* 7.18.2.3 Limits of fastest minimum-width integer types */
 
/* minimum values of fastest minimum-width signed integer types */
#define	INT_FAST8_MIN	(-0x7f-1)			/* int_fast8_t	  */
#define	INT_FAST16_MIN	(-0x7fff-1)			/* int_fast16_t	  */
#define	INT_FAST32_MIN	(-0x7fffffff-1)			/* int_fast32_t	  */
#define	INT_FAST64_MIN	(-0x7fffffffffffffffLL-1)	/* int_fast64_t	  */

/* maximum values of fastest minimum-width signed integer types */
#define	INT_FAST8_MAX	0x7f				/* int_fast8_t	  */
#define	INT_FAST16_MAX	0x7fff				/* int_fast16_t	  */
#define	INT_FAST32_MAX	0x7fffffff			/* int_fast32_t	  */
#define	INT_FAST64_MAX	0x7fffffffffffffffLL		/* int_fast64_t	  */

/* maximum values of fastest minimum-width unsigned integer types */
#define	UINT_FAST8_MAX	0xff				/* uint_fast8_t	  */
#define	UINT_FAST16_MAX	0xffff				/* uint_fast16_t  */
#define	UINT_FAST32_MAX	0xffffffffU			/* uint_fast32_t  */
#define	UINT_FAST64_MAX	0xffffffffffffffffULL		/* uint_fast64_t  */

/* 7.18.2.4 Limits of integer types capable of holding object pointers */

#define	INTPTR_MIN	(-0x7fffffff-1)			/* intptr_t	  */
#define	INTPTR_MAX	0x7fffffff			/* intptr_t	  */
#define	UINTPTR_MAX	0xffffffffU			/* uintptr_t	  */

/* 7.18.2.5 Limits of greatest-width integer types */

#define	INTMAX_MIN	(-0x7fffffffffffffffLL-1)	/* intmax_t	  */
#define	INTMAX_MAX	0x7fffffffffffffffLL		/* intmax_t	  */
#define	UINTMAX_MAX	0xffffffffffffffffULL		/* uintmax_t	  */


/*
 * 7.18.3 Limits of other integer types
 */

/* limits of ptrdiff_t */
#define	PTRDIFF_MIN	(-0x7fffffff-1)			/* ptrdiff_t	  */
#define	PTRDIFF_MAX	0x7fffffff			/* ptrdiff_t	  */

/* limits of sig_atomic_t */
#define	SIG_ATOMIC_MIN	(-0x7fffffff-1)			/* sig_atomic_t	  */
#define	SIG_ATOMIC_MAX	0x7fffffff			/* sig_atomic_t	  */

/* limit of size_t */
#define	SIZE_MAX	0xffffffffU			/* size_t	  */

#endif /* !__SIG_ATOMIC_MAX__ */

#endif /* !_M68K_INT_LIMITS_H_ */