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

#ifndef _XLOCALE__INTTYPES_H_
#define _XLOCALE__INTTYPES_H_

#include <sys/cdefs.h>
#include <stdint.h>
#include <_xlocale.h>

__BEGIN_DECLS
intmax_t  strtoimax_l(const char * __restrict nptr, char ** __restrict endptr,
		int base, locale_t);
uintmax_t strtoumax_l(const char * __restrict nptr, char ** __restrict endptr,
		int base, locale_t);
intmax_t  wcstoimax_l(const wchar_t * __restrict nptr,
		wchar_t ** __restrict endptr, int base, locale_t);
uintmax_t wcstoumax_l(const wchar_t * __restrict nptr,
		wchar_t ** __restrict endptr, int base, locale_t);

/* Poison the following routines if -fshort-wchar is set */
#if !defined(__cplusplus) && defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 0xffffU
#pragma GCC poison wcstoimax_l wcstoumax_l
#endif
__END_DECLS

#endif /* _XLOCALE__INTTYPES_H_ */
