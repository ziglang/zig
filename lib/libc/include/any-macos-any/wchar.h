/*-
 * Copyright (c)1999 Citrus Project,
 * All rights reserved.
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
 *
 * $FreeBSD: /repoman/r/ncvs/src/include/wchar.h,v 1.34 2003/03/13 06:29:53 tjr Exp $
 */

/*-
 * Copyright (c) 1999, 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Julian Coleman.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *        This product includes software developed by the NetBSD
 *        Foundation, Inc. and its contributors.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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
 *
 *	$NetBSD: wchar.h,v 1.8 2000/12/22 05:31:42 itojun Exp $
 */

#ifndef _WCHAR_H_
#define _WCHAR_H_

#include <_types.h>
#include <sys/cdefs.h>
#include <Availability.h>

#include <sys/_types/_null.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_mbstate_t.h>
#include <sys/_types/_ct_rune_t.h>
#include <sys/_types/_rune_t.h>
#include <sys/_types/_wchar_t.h>

#ifndef WCHAR_MIN
#define WCHAR_MIN	__DARWIN_WCHAR_MIN
#endif

#ifndef WCHAR_MAX
#define WCHAR_MAX	__DARWIN_WCHAR_MAX
#endif

#include <stdarg.h>
#include <stdio.h>
#include <time.h>
#include <_wctype.h>


/* Initially added in Issue 4 */
__BEGIN_DECLS
wint_t	btowc(int);
wint_t	fgetwc(FILE *);
wchar_t	*fgetws(wchar_t * __restrict, int, FILE * __restrict);
wint_t	fputwc(wchar_t, FILE *);
int	fputws(const wchar_t * __restrict, FILE * __restrict);
int	fwide(FILE *, int);
int	fwprintf(FILE * __restrict, const wchar_t * __restrict, ...);
int	fwscanf(FILE * __restrict, const wchar_t * __restrict, ...);
wint_t	getwc(FILE *);
wint_t	getwchar(void);
size_t	mbrlen(const char * __restrict, size_t, mbstate_t * __restrict);
size_t	mbrtowc(wchar_t * __restrict, const char * __restrict, size_t,
	    mbstate_t * __restrict);
int	mbsinit(const mbstate_t *);
size_t	mbsrtowcs(wchar_t * __restrict, const char ** __restrict, size_t,
	    mbstate_t * __restrict);
wint_t	putwc(wchar_t, FILE *);
wint_t	putwchar(wchar_t);
int	swprintf(wchar_t * __restrict, size_t, const wchar_t * __restrict, ...);
int	swscanf(const wchar_t * __restrict, const wchar_t * __restrict, ...);
wint_t	ungetwc(wint_t, FILE *);
int	vfwprintf(FILE * __restrict, const wchar_t * __restrict,
	    __darwin_va_list);
int	vswprintf(wchar_t * __restrict, size_t, const wchar_t * __restrict,
	    __darwin_va_list);
int	vwprintf(const wchar_t * __restrict, __darwin_va_list);
size_t	wcrtomb(char * __restrict, wchar_t, mbstate_t * __restrict);
wchar_t	*wcscat(wchar_t * __restrict, const wchar_t * __restrict);
wchar_t	*wcschr(const wchar_t *, wchar_t);
int	wcscmp(const wchar_t *, const wchar_t *);
int	wcscoll(const wchar_t *, const wchar_t *);
wchar_t	*wcscpy(wchar_t * __restrict, const wchar_t * __restrict);
size_t	wcscspn(const wchar_t *, const wchar_t *);
size_t	wcsftime(wchar_t * __restrict, size_t, const wchar_t * __restrict,
	    const struct tm * __restrict) __DARWIN_ALIAS(wcsftime);
size_t	wcslen(const wchar_t *);
wchar_t	*wcsncat(wchar_t * __restrict, const wchar_t * __restrict, size_t);
int	wcsncmp(const wchar_t *, const wchar_t *, size_t);
wchar_t	*wcsncpy(wchar_t * __restrict , const wchar_t * __restrict, size_t);
wchar_t	*wcspbrk(const wchar_t *, const wchar_t *);
wchar_t	*wcsrchr(const wchar_t *, wchar_t);
size_t	wcsrtombs(char * __restrict, const wchar_t ** __restrict, size_t,
	    mbstate_t * __restrict);
size_t	wcsspn(const wchar_t *, const wchar_t *);
wchar_t	*wcsstr(const wchar_t * __restrict, const wchar_t * __restrict);
size_t	wcsxfrm(wchar_t * __restrict, const wchar_t * __restrict, size_t);
int	wctob(wint_t);
double	wcstod(const wchar_t * __restrict, wchar_t ** __restrict);
wchar_t	*wcstok(wchar_t * __restrict, const wchar_t * __restrict,
	    wchar_t ** __restrict);
long	 wcstol(const wchar_t * __restrict, wchar_t ** __restrict, int);
unsigned long
	 wcstoul(const wchar_t * __restrict, wchar_t ** __restrict, int);
wchar_t	*wmemchr(const wchar_t *, wchar_t, size_t);
int	wmemcmp(const wchar_t *, const wchar_t *, size_t);
wchar_t	*wmemcpy(wchar_t * __restrict, const wchar_t * __restrict, size_t);
wchar_t	*wmemmove(wchar_t *, const wchar_t *, size_t);
wchar_t	*wmemset(wchar_t *, wchar_t, size_t);
int	wprintf(const wchar_t * __restrict, ...);
int	wscanf(const wchar_t * __restrict, ...);
int	wcswidth(const wchar_t *, size_t);
int	wcwidth(wchar_t);
__END_DECLS



/* Additional functionality provided by:
 * POSIX.1-2001
 * ISO C99
 */

#if __DARWIN_C_LEVEL >= 200112L || defined(_C99_SOURCE) || defined(__cplusplus)
__BEGIN_DECLS
int	vfwscanf(FILE * __restrict, const wchar_t * __restrict,
	    __darwin_va_list);
int	vswscanf(const wchar_t * __restrict, const wchar_t * __restrict,
	    __darwin_va_list);
int	vwscanf(const wchar_t * __restrict, __darwin_va_list);
float	wcstof(const wchar_t * __restrict, wchar_t ** __restrict);
long double
	wcstold(const wchar_t * __restrict, wchar_t ** __restrict);
#if !__DARWIN_NO_LONG_LONG
long long
	wcstoll(const wchar_t * __restrict, wchar_t ** __restrict, int);
unsigned long long
	wcstoull(const wchar_t * __restrict, wchar_t ** __restrict, int);
#endif /* !__DARWIN_NO_LONG_LONG */
__END_DECLS
#endif



/* Additional functionality provided by:
 * POSIX.1-2008
 */

#if __DARWIN_C_LEVEL >= 200809L
__BEGIN_DECLS
size_t  mbsnrtowcs(wchar_t * __restrict, const char ** __restrict, size_t,
            size_t, mbstate_t * __restrict);
wchar_t *wcpcpy(wchar_t * __restrict, const wchar_t * __restrict) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
wchar_t *wcpncpy(wchar_t * __restrict, const wchar_t * __restrict, size_t) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
wchar_t *wcsdup(const wchar_t *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int     wcscasecmp(const wchar_t *, const wchar_t *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int     wcsncasecmp(const wchar_t *, const wchar_t *, size_t n) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
size_t  wcsnlen(const wchar_t *, size_t) __pure __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
size_t  wcsnrtombs(char * __restrict, const wchar_t ** __restrict, size_t,
            size_t, mbstate_t * __restrict);
FILE *open_wmemstream(wchar_t ** __bufp, size_t * __sizep) __API_AVAILABLE(macos(10.13), ios(11.0), tvos(11.0), watchos(4.0));
__END_DECLS
#endif /* __DARWIN_C_LEVEL >= 200809L */



/* Darwin extensions */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
__BEGIN_DECLS
wchar_t *fgetwln(FILE * __restrict, size_t *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
size_t	wcslcat(wchar_t *, const wchar_t *, size_t);
size_t	wcslcpy(wchar_t *, const wchar_t *, size_t);
__END_DECLS
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */


/* Poison the following routines if -fshort-wchar is set */
#if !defined(__cplusplus) && defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 0xffffU
#pragma GCC poison fgetwln fgetws fputwc fputws fwprintf fwscanf mbrtowc mbsnrtowcs mbsrtowcs putwc putwchar swprintf swscanf vfwprintf vfwscanf vswprintf vswscanf vwprintf vwscanf wcrtomb wcscat wcschr wcscmp wcscoll wcscpy wcscspn wcsftime wcsftime wcslcat wcslcpy wcslen wcsncat wcsncmp wcsncpy wcsnrtombs wcspbrk wcsrchr wcsrtombs wcsspn wcsstr wcstod wcstof wcstok wcstol wcstold wcstoll wcstoul wcstoull wcswidth wcsxfrm wcwidth wmemchr wmemcmp wmemcpy wmemmove wmemset wprintf wscanf
#endif

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_wchar.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* !_WCHAR_H_ */
