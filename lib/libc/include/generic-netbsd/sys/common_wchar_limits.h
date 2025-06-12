/*	$NetBSD: common_wchar_limits.h,v 1.1 2014/08/18 22:21:39 matt Exp $	*/

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

#ifndef _SYS_COMMON_WCHAR_LIMITS_H_
#define _SYS_COMMON_WCHAR_LIMITS_H_

/*
 * 7.18.3 Limits of other integer types
 */

/* limits of wchar_t */

#if !defined(__WCHAR_MIN__) || !defined(__WCHAR_MAX__)
#error __WCHAR_MIN__ or __WCHAR_MAX__ not defined
#endif

#define	WCHAR_MIN	__WCHAR_MIN__			/* wchar_t	  */
#define	WCHAR_MAX	__WCHAR_MAX__			/* wchar_t	  */

/* limits of wint_t */

#if !defined(__WINT_MIN__) || !defined(__WINT_MAX__)
#error __WINT_MIN__ or __WINT_MAX__ not defined
#endif

#define	WINT_MIN	__WINT_MIN__			/* wint_t	  */
#define	WINT_MAX	__WINT_MAX__			/* wint_t	  */

#endif /* !_SYS_COMMON_WCHAR_LIMITS_H_ */