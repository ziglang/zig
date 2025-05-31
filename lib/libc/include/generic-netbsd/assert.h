/*	$NetBSD: assert.h,v 1.25 2020/04/17 15:22:34 kamil Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)assert.h	8.2 (Berkeley) 1/21/94
 */

/*
 * Unlike other ANSI header files, <assert.h> may usefully be included
 * multiple times, with and without NDEBUG defined.
 */

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/null.h>

#undef assert

#ifdef NDEBUG
# ifndef __lint__
#  define assert(e)	(__static_cast(void,0))
# else /* !__lint__ */
#  define assert(e)
# endif /* __lint__ */
#else /* !NDEBUG */
# if __STDC__
#  define assert(e)							\
	((e) ? __static_cast(void,0) : __assert13(__FILE__, __LINE__,	\
	                                          __assert_function__, #e))
# else	/* PCC */
#  define assert(e)							\
	((e) ? __static_cast(void,0) : __assert13(__FILE__, __LINE__,	\
	                                          __assert_function__, "e"))
# endif /* !__STDC__ */
#endif /* NDEBUG */

#undef _DIAGASSERT
#if !defined(_DIAGNOSTIC)
# if !defined(__lint__)
#  define _DIAGASSERT(e) (__static_cast(void,0))
# else /* !__lint__ */
#  define _DIAGASSERT(e)
# endif /* __lint__ */
#else /* _DIAGNOSTIC */
# if __STDC__
#  define _DIAGASSERT(e)						\
	((e) ? __static_cast(void,0) : __diagassert13(__FILE__, __LINE__, \
	                                              __assert_function__, #e))
# else	/* !__STDC__ */
#  define _DIAGASSERT(e)	 					\
	((e) ? __static_cast(void,0) : __diagassert13(__FILE__, __LINE__, \
	                                              __assert_function__, "e"))
# endif
#endif /* _DIAGNOSTIC */


#if defined(__lint__)
#define	__assert_function__	(__static_cast(const void *,0))
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#define	__assert_function__	__func__
#elif __GNUC_PREREQ__(2, 6)
#define	__assert_function__	__PRETTY_FUNCTION__
#else
#define	__assert_function__	(__static_cast(const void *,0))
#endif

#ifndef __ASSERT_DECLARED
#define __ASSERT_DECLARED
__BEGIN_DECLS
__dead void __assert(const char *, int, const char *);
__dead void __assert13(const char *, int, const char *, const char *);
void __diagassert(const char *, int, const char *);
void __diagassert13(const char *, int, const char *, const char *);
__END_DECLS
#endif /* __ASSERT_DECLARED */

#if defined(_ISOC11_SOURCE) || (__STDC_VERSION__ - 0) >= 201101L
#ifndef static_assert
#define static_assert _Static_assert
#endif /* static_assert */
#endif