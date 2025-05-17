/*	$NetBSD: wchar.h,v 1.44 2020/03/20 01:08:42 joerg Exp $	*/

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

#ifndef _WCHAR_H_
#define _WCHAR_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/wchar_limits.h>
#include <sys/ansi.h>
#include <sys/null.h>

#include <stdio.h> /* for FILE* */

#if defined(_BSD_WCHAR_T_) && !defined(__cplusplus)
typedef	_BSD_WCHAR_T_	wchar_t;
#undef	_BSD_WCHAR_T_
#endif

#ifdef	_BSD_MBSTATE_T_
typedef	_BSD_MBSTATE_T_	mbstate_t;
#undef	_BSD_MBSTATE_T_
#endif

#ifdef	_BSD_WINT_T_
typedef	_BSD_WINT_T_	wint_t;
#undef	_BSD_WINT_T_
#endif

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#if defined(_POSIX_C_SOURCE)
#ifndef __VA_LIST_DECLARED
typedef __va_list va_list;
#define __VA_LIST_DECLARED
#endif
#endif

struct tm;

__BEGIN_DECLS
wint_t	btowc(int);
size_t	mbrlen(const char * __restrict, size_t, mbstate_t * __restrict);
size_t	mbrtowc(wchar_t * __restrict, const char * __restrict, size_t,
	    mbstate_t * __restrict);
int	mbsinit(const mbstate_t *);
size_t	mbsrtowcs(wchar_t * __restrict, const char ** __restrict, size_t,
	    mbstate_t * __restrict);
size_t	wcrtomb(char * __restrict, wchar_t, mbstate_t * __restrict);
wchar_t	*wcscat(wchar_t * __restrict, const wchar_t * __restrict);
wchar_t	*wcschr(const wchar_t *, wchar_t);
int	wcscmp(const wchar_t *, const wchar_t *);
int	wcscoll(const wchar_t *, const wchar_t *);
wchar_t	*wcscpy(wchar_t * __restrict, const wchar_t * __restrict);
size_t	wcscspn(const wchar_t *, const wchar_t *);
size_t	wcsftime(wchar_t * __restrict, size_t, const wchar_t * __restrict,
	    const struct tm * __restrict);
size_t	wcslen(const wchar_t *);
wchar_t	*wcsncat(wchar_t * __restrict, const wchar_t * __restrict, size_t);
int	wcsncmp(const wchar_t *, const wchar_t *, size_t);
wchar_t	*wcsncpy(wchar_t * __restrict , const wchar_t * __restrict, size_t);
size_t	wcsnlen(const wchar_t *, size_t);
wchar_t	*wcspbrk(const wchar_t *, const wchar_t *);
wchar_t	*wcsrchr(const wchar_t *, wchar_t);
size_t	wcsrtombs(char * __restrict, const wchar_t ** __restrict, size_t,
	    mbstate_t * __restrict);
size_t	wcsspn(const wchar_t *, const wchar_t *);
wchar_t	*wcsstr(const wchar_t *, const wchar_t *);
wchar_t *wcstok(wchar_t * __restrict, const wchar_t * __restrict,
		     wchar_t ** __restrict);
size_t	wcsxfrm(wchar_t *, const wchar_t *, size_t);
wchar_t	*wcswcs(const wchar_t *, const wchar_t *);
wchar_t	*wmemchr(const wchar_t *, wchar_t, size_t);
int	wmemcmp(const wchar_t *, const wchar_t *, size_t);
wchar_t	*wmemcpy(wchar_t * __restrict, const wchar_t * __restrict, size_t);
wchar_t	*wmemmove(wchar_t *, const wchar_t *, size_t);
wchar_t	*wmemset(wchar_t *, wchar_t, size_t);

#if defined(_NETBSD_SOURCE)
size_t	wcslcat(wchar_t *, const wchar_t *, size_t);
size_t	wcslcpy(wchar_t *, const wchar_t *, size_t);
#endif

#if defined(_NETBSD_SOURCE) || \
    (_POSIX_C_SOURCE - 0 >= 200112L) || (_XOPEN_SOURCE - 0) >= 600
int	wcswidth(const wchar_t *, size_t);
int	wcwidth(wchar_t);
#endif

int	wctob(wint_t);
unsigned long int wcstoul(const wchar_t * __restrict,
	wchar_t ** __restrict, int);
long int wcstol(const wchar_t * __restrict,
	wchar_t ** __restrict, int);
double wcstod(const wchar_t * __restrict, wchar_t ** __restrict);

#if defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) >= 199901L || \
    (__cplusplus - 0) >= 201103L || defined(_NETBSD_SOURCE) || \
    (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 600
float wcstof(const wchar_t * __restrict, wchar_t ** __restrict);
long double wcstold(const wchar_t * __restrict, wchar_t ** __restrict);

/* LONGLONG */
long long int wcstoll(const wchar_t * __restrict,
	wchar_t ** __restrict, int);
/* LONGLONG */
unsigned long long int wcstoull(const wchar_t * __restrict,
	wchar_t ** __restrict, int);
#endif

#if (_POSIX_C_SOURCE - 0) >= 200809L || (_XOPEN_SOURCE - 0) >= 700 || \
    defined(_NETBSD_SOURCE)
FILE	*open_wmemstream(wchar_t **, size_t *);
#endif

wint_t ungetwc(wint_t, FILE *);
wint_t fgetwc(FILE *);
wchar_t *fgetws(wchar_t * __restrict, int, FILE * __restrict);
wint_t getwc(FILE *);
wint_t getwchar(void);
wint_t fputwc(wchar_t, FILE *);
int fputws(const wchar_t * __restrict, FILE * __restrict);
wint_t putwc(wchar_t, FILE *);
wint_t putwchar(wchar_t);

int fwide(FILE *, int);

wchar_t	*fgetwln(FILE * __restrict, size_t * __restrict);
int fwprintf(FILE * __restrict, const wchar_t * __restrict, ...);
int fwscanf(FILE * __restrict, const wchar_t * __restrict, ...);
int swprintf(wchar_t * __restrict, size_t n, const wchar_t * __restrict, ...);
int swscanf(const wchar_t * __restrict, const wchar_t * __restrict, ...);
int vfwprintf(FILE * __restrict, const wchar_t * __restrict, __va_list);
int vswprintf(wchar_t * __restrict, size_t, const wchar_t * __restrict,
    __va_list);
int vwprintf(const wchar_t * __restrict, __va_list);
int wprintf(const wchar_t * __restrict, ...);
int wscanf(const wchar_t * __restrict, ...);
#if defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) > 199901L || \
    (__cplusplus - 0) >= 201103L || defined(_NETBSD_SOURCE) || \
    (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 600
int vfwscanf(FILE * __restrict, const wchar_t * __restrict, __va_list);
int vswscanf(const wchar_t * __restrict, const wchar_t * __restrict,
    __va_list);
int vwscanf(const wchar_t * __restrict, __va_list);
#endif
#if defined(_NETBSD_SOURCE)
struct tinfo;
int t_putws(struct tinfo *, const wchar_t *, int, void (*)(wchar_t, void *),
    void *);
wchar_t *wcsdup (const wchar_t *);
int wcsncasecmp (const wchar_t *, const wchar_t *, size_t);
int wcscasecmp(const wchar_t *, const wchar_t *);
#endif
__END_DECLS

#ifndef WEOF
#define	WEOF 	((wint_t)-1)
#endif

#define getwc(f) fgetwc(f)
#define getwchar() getwc(stdin)
#define putwc(wc, f) fputwc((wc), (f))
#define putwchar(wc) putwc((wc), stdout)

#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
__BEGIN_DECLS
size_t	mbsnrtowcs(wchar_t * __restrict, const char ** __restrict, size_t,
	    size_t, mbstate_t * __restrict);
size_t	wcsnrtombs(char * __restrict, const wchar_t ** __restrict, size_t,
	    size_t, mbstate_t * __restrict);

int	wcscoll_l(const wchar_t *, const wchar_t *, locale_t);
size_t	wcsxfrm_l(wchar_t *, const wchar_t *, size_t, locale_t);
int wcsncasecmp_l(const wchar_t *, const wchar_t *, size_t, locale_t);
int wcscasecmp_l(const wchar_t *, const wchar_t *, locale_t);

size_t	wcsftime_l(wchar_t * __restrict, size_t, const wchar_t * __restrict,
	    const struct tm * __restrict, locale_t);

float wcstof_l(const wchar_t * __restrict, wchar_t ** __restrict, locale_t);
double wcstod_l(const wchar_t * __restrict, wchar_t ** __restrict, locale_t);
long double wcstold_l(const wchar_t * __restrict, wchar_t ** __restrict,
    locale_t);
long int wcstol_l(const wchar_t * __restrict, wchar_t ** __restrict, int,
		  locale_t);
unsigned long int wcstoul_l(const wchar_t * __restrict,
	wchar_t ** __restrict, int, locale_t);
/* LONGLONG */
long long int wcstoll_l(const wchar_t * __restrict, wchar_t ** __restrict, int,
			locale_t);
/* LONGLONG */
unsigned long long int wcstoull_l(const wchar_t * __restrict,
				  wchar_t ** __restrict, int, locale_t);
int	wcwidth_l(wchar_t, locale_t);
int	wcswidth_l(const wchar_t *, size_t, locale_t);
__END_DECLS
#endif /* _POSIX_C_SOURCE || _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE)
__BEGIN_DECLS
wint_t	btowc_l(int, locale_t);
size_t	mbrlen_l(const char * __restrict, size_t, mbstate_t * __restrict,
		locale_t);
size_t	mbrtowc_l(wchar_t * __restrict, const char * __restrict, size_t,
	    mbstate_t * __restrict, locale_t);
int	mbsinit_l(const mbstate_t *, locale_t);
size_t	mbsrtowcs_l(wchar_t * __restrict, const char ** __restrict, size_t,
	    mbstate_t * __restrict, locale_t);
size_t	mbsnrtowcs_l(wchar_t * __restrict, const char ** __restrict, size_t,
	    size_t, mbstate_t * __restrict, locale_t);
size_t	wcrtomb_l(char * __restrict, wchar_t, mbstate_t * __restrict, locale_t);
size_t	wcsrtombs_l(char * __restrict, const wchar_t ** __restrict, size_t,
	    mbstate_t * __restrict, locale_t);
size_t	wcsnrtombs_l(char * __restrict, const wchar_t ** __restrict, size_t,
	    size_t, mbstate_t * __restrict, locale_t);
int	wctob_l(wint_t, locale_t);

int fwprintf_l(FILE * __restrict, locale_t, const wchar_t * __restrict, ...);
int swprintf_l(wchar_t * __restrict, size_t n, locale_t,
    const wchar_t * __restrict, ...);
int vfwprintf_l(FILE * __restrict, locale_t,
    const wchar_t * __restrict, __va_list);
int vswprintf_l(wchar_t * __restrict, size_t, locale_t,
    const wchar_t * __restrict, __va_list);
int vwprintf_l(locale_t, const wchar_t * __restrict, __va_list);
int wprintf_l(locale_t, const wchar_t * __restrict, ...);

int fwscanf_l(FILE * __restrict, locale_t, const wchar_t * __restrict, ...);
int swscanf_l(const wchar_t * __restrict, locale_t, const wchar_t *
    __restrict, ...);
int wscanf_l(locale_t, const wchar_t * __restrict, ...);
int vfwscanf_l(FILE * __restrict, locale_t, const wchar_t * __restrict,
    __va_list);
int vswscanf_l(const wchar_t * __restrict, locale_t, const wchar_t * __restrict,
    __va_list);
int vwscanf_l(locale_t, const wchar_t * __restrict, __va_list);
__END_DECLS
#endif /* _NETBSD_SOURCE */

#endif /* !_WCHAR_H_ */