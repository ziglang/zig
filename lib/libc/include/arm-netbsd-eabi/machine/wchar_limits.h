/*	$NetBSD: wchar_limits.h,v 1.4 2013/01/24 10:17:00 matt Exp $	*/

/*-
 * Copyright (c) 2004 The NetBSD Foundation, Inc.
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

#ifndef _ARM_WCHAR_LIMITS_H_
#define _ARM_WCHAR_LIMITS_H_

/*
 * 7.18.3 Limits of other integer types
 */

/* limits of wchar_t */

#ifdef __WCHAR_MIN__
#define	WCHAR_MIN	__WCHAR_MIN__			/* wchar_t	  */
#elif __WCHAR_UNSIGNED__
#define	WCHAR_MIN	0U				/* wchar_t	  */
#else
#define	WCHAR_MIN	(-0x7fffffff-1)			/* wchar_t	  */
#endif

#ifdef __WCHAR_MAX__
#define	WCHAR_MAX	__WCHAR_MAX__			/* wchar_t	  */
#elif __WCHAR_UNSIGNED__
#define	WCHAR_MAX	0xffffffffU			/* wchar_t	  */
#else
#define	WCHAR_MAX	0x7fffffff			/* wchar_t	  */
#endif

/* limits of wint_t */

#ifdef __WINT_MIN__
#define	WINT_MIN	__WINT_MIN__			/* wint_t	  */
#elif __WINT_UNSIGNED__
#define	WINT_MIN	0U				/* wint_t	  */
#else
#define	WINT_MIN	(-0x7fffffff-1)			/* wint_t	  */
#endif

#ifdef __WINT_MAX__
#define	WINT_MAX	__WINT_MAX__			/* wint_t	  */
#elif __WINT_UNSIGNED__
#define	WINT_MAX	0xffffffffU			/* wint_t	  */
#else
#define	WINT_MAX	0x7fffffff			/* wint_t	  */
#endif

#endif /* !_ARM_WCHAR_LIMITS_H_ */