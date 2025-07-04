/*	$NetBSD: inttypes.h,v 1.11 2015/01/16 18:35:59 christos Exp $	*/

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

#ifndef _INTTYPES_H_
#define _INTTYPES_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/inttypes.h>
#include <machine/ansi.h>

#if defined(_BSD_WCHAR_T_) && !defined(__cplusplus)
typedef	_BSD_WCHAR_T_	wchar_t;
#undef	_BSD_WCHAR_T_
#endif

__BEGIN_DECLS
intmax_t	strtoimax(const char * __restrict,
		    char ** __restrict, int);
uintmax_t	strtoumax(const char * __restrict,
		    char ** __restrict, int);
intmax_t	wcstoimax(const wchar_t * __restrict,
		    wchar_t ** __restrict, int);
uintmax_t	wcstoumax(const wchar_t * __restrict,
		    wchar_t ** __restrict, int);

intmax_t	imaxabs(intmax_t);

typedef struct {
	intmax_t quot;
	intmax_t rem;
} imaxdiv_t;

imaxdiv_t	imaxdiv(intmax_t, intmax_t);

#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
intmax_t	strtoimax_l(const char * __restrict,
		    char ** __restrict, int, locale_t);
uintmax_t	strtoumax_l(const char * __restrict,
		    char ** __restrict, int, locale_t);
intmax_t	wcstoimax_l(const wchar_t * __restrict,
		    wchar_t ** __restrict, int, locale_t);
uintmax_t	wcstoumax_l(const wchar_t * __restrict,
		    wchar_t ** __restrict, int, locale_t);
#endif


#if defined(_NETBSD_SOURCE)
intmax_t	strtoi(const char * __restrict, char ** __restrict, int,
	               intmax_t, intmax_t, int *);
uintmax_t	strtou(const char * __restrict, char ** __restrict, int,
	               uintmax_t, uintmax_t, int *);

/* i18n variations */
intmax_t	strtoi_l(const char * __restrict, char ** __restrict, int,
	                 intmax_t, intmax_t, int *, locale_t);
uintmax_t	strtou_l(const char * __restrict, char ** __restrict, int,
	                 uintmax_t, uintmax_t, int *, locale_t);
#endif /* defined(_NETBSD_SOURCE) */

__END_DECLS

#endif /* !_INTTYPES_H_ */