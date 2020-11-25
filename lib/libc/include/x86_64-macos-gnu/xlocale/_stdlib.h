/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _XLOCALE__STDLIB_H_
#define _XLOCALE__STDLIB_H_

#include <sys/cdefs.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_wchar_t.h>
#include <_xlocale.h>

__BEGIN_DECLS
double	 atof_l(const char *, locale_t);
int	 atoi_l(const char *, locale_t);
long	 atol_l(const char *, locale_t);
#if !__DARWIN_NO_LONG_LONG
long long
	 atoll_l(const char *, locale_t);
#endif /* !__DARWIN_NO_LONG_LONG */
int	 mblen_l(const char *, size_t, locale_t);
size_t	 mbstowcs_l(wchar_t * __restrict , const char * __restrict, size_t,
	    locale_t);
int	 mbtowc_l(wchar_t * __restrict, const char * __restrict, size_t,
	    locale_t);
double	 strtod_l(const char *, char **, locale_t) __DARWIN_ALIAS(strtod_l);
float	 strtof_l(const char *, char **, locale_t) __DARWIN_ALIAS(strtof_l);
long	 strtol_l(const char *, char **, int, locale_t);
long double
	 strtold_l(const char *, char **, locale_t);
long long
	 strtoll_l(const char *, char **, int, locale_t);
#if !__DARWIN_NO_LONG_LONG
long long
	 strtoq_l(const char *, char **, int, locale_t);
#endif /* !__DARWIN_NO_LONG_LONG */
unsigned long
	 strtoul_l(const char *, char **, int, locale_t);
unsigned long long
	 strtoull_l(const char *, char **, int, locale_t);
#if !__DARWIN_NO_LONG_LONG
unsigned long long
	 strtouq_l(const char *, char **, int, locale_t);
#endif /* !__DARWIN_NO_LONG_LONG */
size_t	 wcstombs_l(char * __restrict, const wchar_t * __restrict, size_t,
	    locale_t);
int	 wctomb_l(char *, wchar_t, locale_t);

/* Poison the following routines if -fshort-wchar is set */
#if !defined(__cplusplus) && defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 0xffffU
#pragma GCC poison mbstowcs_l mbtowc_l wcstombs_l wctomb_l
#endif
__END_DECLS

#endif /* _XLOCALE__STDLIB_H_ */
