/*
 * Copyright (c) 2007, 2010 Apple Inc. All rights reserved.
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

#ifndef _STDIO_H_
 #error error "Never use <secure/_stdio.h> directly; include <stdio.h> instead."
#endif

#ifndef _SECURE__STDIO_H_
#define _SECURE__STDIO_H_

#include <secure/_common.h>

#if _USE_FORTIFY_LEVEL > 0

#ifndef __has_builtin
#define _undef__has_builtin
#define __has_builtin(x) 0
#endif

/* sprintf, vsprintf, snprintf, vsnprintf */
#if __has_builtin(__builtin___sprintf_chk) || defined(__GNUC__)
extern int __sprintf_chk (char * __restrict, int, size_t,
			  const char * __restrict, ...);

#undef sprintf
#define sprintf(str, ...) \
  __builtin___sprintf_chk (str, 0, __darwin_obsz(str), __VA_ARGS__)
#endif

#if __DARWIN_C_LEVEL >= 200112L
#if __has_builtin(__builtin___snprintf_chk) || defined(__GNUC__)
extern int __snprintf_chk (char * __restrict, size_t, int, size_t,
			   const char * __restrict, ...);

#undef snprintf
#define snprintf(str, len, ...) \
  __builtin___snprintf_chk (str, len, 0, __darwin_obsz(str), __VA_ARGS__)
#endif

#if __has_builtin(__builtin___vsprintf_chk) || defined(__GNUC__)
extern int __vsprintf_chk (char * __restrict, int, size_t,
			   const char * __restrict, va_list);

#undef vsprintf
#define vsprintf(str, format, ap) \
  __builtin___vsprintf_chk (str, 0, __darwin_obsz(str), format, ap)
#endif

#if __has_builtin(__builtin___vsnprintf_chk) || defined(__GNUC__)
extern int __vsnprintf_chk (char * __restrict, size_t, int, size_t,
			    const char * __restrict, va_list);

#undef vsnprintf
#define vsnprintf(str, len, format, ap) \
  __builtin___vsnprintf_chk (str, len, 0, __darwin_obsz(str), format, ap)
#endif

#endif /* __DARWIN_C_LEVEL >= 200112L */

#ifdef _undef__has_builtin
#undef _undef__has_builtin
#undef __has_builtin
#endif

#endif /* _USE_FORTIFY_LEVEL > 0 */
#endif /* _SECURE__STDIO_H_ */