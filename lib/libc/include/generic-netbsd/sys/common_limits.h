/*	$NetBSD: common_limits.h,v 1.3 2019/01/21 20:29:27 dholland Exp $	*/

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef _SYS_COMMON_LIMITS_H_
#define _SYS_COMMON_LIMITS_H_

#define	CHAR_BIT	__CHAR_BIT__	/* number of bits in a char */

#define SCHAR_MIN	(-__SCHAR_MAX__-1) /* min value for a signed char */
#define	SCHAR_MAX	__SCHAR_MAX__	/* max value for a signed char */
#define	UCHAR_MAX	(2*SCHAR_MAX+1)	/* max value for an unsigned char */

#define	SHRT_MIN	(-__SHRT_MAX__-1) /* min value for a short */
#define	SHRT_MAX	__SHRT_MAX__	/* max value for a short */
#define	USHRT_MAX	(2*SHRT_MAX+1)	/* max value for an unsigned short */

#define	INT_MIN		(-__INT_MAX__-1) /* min value for an int */
#define	INT_MAX		__INT_MAX__	/* max value for an int */
#define	UINT_MAX	(2U*INT_MAX+1U)	/* max value for an unsigned int */

#define	LONG_MIN	(-__LONG_MAX__-1L)	/* min value for a long */
#define	LONG_MAX	__LONG_MAX__		/* max value for a long */
#define	ULONG_MAX	(2UL*LONG_MAX+1UL)	/* max unsigned long */

#if defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) >= 199901L || \
    defined(_NETBSD_SOURCE)
#define	LLONG_MIN	(-__LONG_LONG_MAX__-1LL) /* min signed long long */
#define	LLONG_MAX	__LONG_LONG_MAX__	/* max signed long long */
#define	ULLONG_MAX	(2ULL*LLONG_MAX+1ULL)	/* max unsigned long long */
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
#define	SSIZE_MAX	LONG_MAX	/* max value for a ssize_t */

#if defined(_NETBSD_SOURCE)
#define	SSIZE_MIN	LONG_MIN	/* min value for a ssize_t */
#define	SIZE_T_MAX	ULONG_MAX	/* max value for a size_t */

#define	UQUAD_MAX	ULLONG_MAX	/* max unsigned quad */
#define	QUAD_MAX	LLONG_MAX	/* max signed quad */
#define	QUAD_MIN	LLONG_MIN	/* min signed quad */

#endif /* _NETBSD_SOURCE */
#endif /* _POSIX_C_SOURCE || _XOPEN_SOURCE || _NETBSD_SOURCE */

#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
#define LONG_BIT	(__SIZEOF_LONG__ * 8)
#define WORD_BIT	(__SIZEOF_INT__ * 8)

#define DBL_DIG		__DBL_DIG__
#define DBL_MAX		__DBL_MAX__
#define DBL_MIN		__DBL_MIN__

#define FLT_DIG		__FLT_DIG__
#define FLT_MAX		__FLT_MAX__
#define FLT_MIN		__FLT_MIN__

#ifdef __LDBL_DIG__
#define LDBL_DIG	__LDBL_DIG__
#define LDBL_MAX	__LDBL_MAX__
#define LDBL_MIN	__LDBL_MIN__
#endif

#endif /* _XOPEN_SOURCE || _NETBSD_SOURCE */

#endif /* _SYS_COMMON_LIMITS_H_ */