/*	$NetBSD: common_ansi.h,v 1.1 2014/08/19 07:27:31 matt Exp $	*/

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

#ifndef _SYS_COMMON_ANSI_H_
#define _SYS_COMMON_ANSI_H_

#include <sys/cdefs.h>

#include <machine/int_types.h>

#if !defined(__PTRDIFF_TYPE__)
#error __PTRDIFF_TYPE__ not present
#endif

#if !defined(__SIZE_TYPE__)
#error __SIZE_TYPE__ not present
#endif

#if !defined(__WCHAR_TYPE__)
#error __WCHAR_TYPE__ not present
#endif

#if !defined(__WINT_TYPE__)
#error __WINT_TYPE__ not present
#endif

/*
 * Types which are fundamental to the implementation and may appear in
 * more than one standard header are defined here.  Standard headers
 * then use:
 *	#ifdef	_BSD_SIZE_T_
 *	typedef	_BSD_SIZE_T_ size_t;
 *	#undef	_BSD_SIZE_T_
 *	#endif
 */
#define	_BSD_CLOCK_T_		unsigned int	/* clock() */
#define	_BSD_PTRDIFF_T_		__PTRDIFF_TYPE__ /* ptr1 - ptr2 */
#define	_BSD_SSIZE_T_		__PTRDIFF_TYPE__ /* byte count or error */
#define	_BSD_SIZE_T_		__SIZE_TYPE__	/* sizeof() */
#define	_BSD_TIME_T_		__int64_t	/* time() */
#define	_BSD_CLOCKID_T_		int		/* clockid_t */
#define	_BSD_TIMER_T_		int		/* timer_t */
#define	_BSD_SUSECONDS_T_	int		/* suseconds_t */
#define	_BSD_USECONDS_T_	unsigned int	/* useconds_t */
#define	_BSD_WCHAR_T_		__WCHAR_TYPE__	/* wchar_t */
#define	_BSD_WINT_T_		__WINT_TYPE__	/* wint_t */

#endif	/* _SYS_COMMON_ANSI_H_ */