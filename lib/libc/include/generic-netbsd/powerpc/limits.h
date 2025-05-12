/*	$NetBSD: limits.h,v 1.20 2019/01/21 20:28:18 dholland Exp $	*/

/*
 * Copyright (c) 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)limits.h	8.3 (Berkeley) 1/4/94
 */

#ifndef	_POWERPC_LIMITS_H_
#define	_POWERPC_LIMITS_H_

#include <sys/featuretest.h>

#define	CHAR_BIT	8		/* number of bits in a char */

/*
 * According to ANSI (section 2.2.4.2), the values below must be usable by
 * #if preprocessing directives.  Additionally, the expression must have the
 * same type as would an expression that is an object of the corresponding
 * type converted according to the integral promotions.  The subtraction for
 * INT_MIN and LONG_MIN is so the value is not unsigned; 2147483648 is an
 * unsigned int for 32-bit two's complement ANSI compilers (section 3.1.3.2).
 * These numbers work for pcc as well.  The UINT_MAX and ULONG_MAX values
 * are written as hex so that GCC will be quiet about large integer constants.
 */
#define	UCHAR_MAX	0xff		/* max value for an unsigned char */
#define	SCHAR_MAX	0x7f		/* max value for a signed char */
#define	SCHAR_MIN	(-0x7f-1)	/* min value for a signed char */

#define	USHRT_MAX	0xffff		/* max value for an unsigned short */
#define	SHRT_MAX	0x7fff		/* max value for a short */
#define	SHRT_MIN	(-0x7fff-1)	/* min value for a short */

#define	UINT_MAX	0xffffffffU	/* max value for an unsigned int */
#define	INT_MAX		0x7fffffff	/* max value for an int */
#define	INT_MIN		(-0x7fffffff-1)	/* min value for an int */

#ifdef _LP64
#define	ULONG_MAX	0xffffffffffffffffUL	/* max for an unsigned long */
#define	LONG_MAX	0x7fffffffffffffffL	/* max for a long */
#define	LONG_MIN	(-0x7fffffffffffffffL-1) /* min for a long */
#else
#define	ULONG_MAX	0xffffffffUL	/* max value for an unsigned long */
#define	LONG_MAX	0x7fffffffL	/* max value for a long */
#define	LONG_MIN	(-0x7fffffff-1)	/* min value for a long */
#endif

#if defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) >= 199901L || \
    defined(_NETBSD_SOURCE)
#define	ULLONG_MAX	0xffffffffffffffffULL	/* max unsigned long long */
#define	LLONG_MAX	0x7fffffffffffffffLL	/* max signed long long */
#define	LLONG_MIN	(-0x7fffffffffffffffLL-1) /* min signed long long */
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
#ifdef _LP64
#define	SSIZE_MAX	LONG_MAX	/* max value for a ssize_t */
#else
#define	SSIZE_MAX	INT_MAX		/* max value for a ssize_t */
#endif

#if defined(_NETBSD_SOURCE)
#ifdef _LP64
#define	SSIZE_MIN	LONG_MIN	/* min value for a ssize_t */
#define	SIZE_T_MAX	ULONG_MAX	/* max value for a size_t */
#else
#define	SSIZE_MIN	INT_MIN		/* min value for a ssize_t */
#define	SIZE_T_MAX	UINT_MAX	/* max value for a size_t */
#endif

#ifdef _LP64
/* Quads and longs are the same on LP64. */
#define	UQUAD_MAX	(ULONG_MAX)
#define	QUAD_MAX	(LONG_MAX)
#define	QUAD_MIN	(LONG_MIN)
#else
/* GCC requires that quad constants be written as expressions. */
#define	UQUAD_MAX	((u_quad_t)0-1)	/* max value for a uquad_t */
					/* max value for a quad_t */
#define	QUAD_MAX	((quad_t)(UQUAD_MAX >> 1))
#define	QUAD_MIN	(-QUAD_MAX-1)	/* min value for a quad_t */
#endif

#endif /* _NETBSD_SOURCE */
#endif /* _POSIX_C_SOURCE || _XOPEN_SOURCE || _NETBSD_SOURCE */

#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
#ifdef _LP64
#define LONG_BIT	64
#else
#define LONG_BIT	32
#endif
#define WORD_BIT	32

#define DBL_DIG		__DBL_DIG__
#define DBL_MAX		__DBL_MAX__
#define DBL_MIN		__DBL_MIN__

#define FLT_DIG		__FLT_DIG__
#define FLT_MAX		__FLT_MAX__
#define FLT_MIN		__FLT_MIN__
#endif

#endif /* _POWERPC_LIMITS_H_ */