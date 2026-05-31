/*
 * Copyright (c) 2007, 2010, 2023 Apple Inc. All rights reserved.
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

#include <_bounds.h>
#include <secure/_common.h>

_LIBC_SINGLE_BY_DEFAULT()

#if _USE_FORTIFY_LEVEL > 0

extern int __snprintf_chk (char * __restrict _LIBC_COUNT(__maxlen), size_t __maxlen, int, size_t,
			  const char * __restrict, ...);
extern int __vsnprintf_chk (char * __restrict _LIBC_COUNT(__maxlen), size_t __maxlen, int, size_t,
			  const char * __restrict, va_list);

extern int __sprintf_chk (char * __restrict _LIBC_UNSAFE_INDEXABLE, int, size_t,
			  const char * __restrict, ...);
extern int __vsprintf_chk (char * __restrict _LIBC_UNSAFE_INDEXABLE, int, size_t,
			  const char * __restrict, va_list);

#ifdef __LIBC_STAGED_BOUNDS_SAFETY_ATTRIBUTES

/* verify that there are at least __n characters at __str */
static inline char *_LIBC_COUNT(__n)
__libc_ptrchk_strbuf_chk(char *_LIBC_COUNT(__n) __str, size_t __n) { return __str; }

#undef __sprintf_chk_func /* sprintf is unavailable */
#undef __vsprintf_chk_func /* vsprintf is unavailable */

#define __vsnprintf_chk_func(str, len, flag, format, ap) ({ \
	size_t __len = (len); \
	__builtin___vsnprintf_chk (__libc_ptrchk_strbuf_chk(str, __len), __len, flag, __darwin_obsz(str), format, ap); \
})

#define __snprintf_chk_func(str, len, flag, ...) ({ \
	size_t __len = (len); \
	__builtin___snprintf_chk (__libc_ptrchk_strbuf_chk(str, __len), __len, flag, __darwin_obsz(str), __VA_ARGS__); \
})

#else

#ifndef __has_builtin
#define __undef__has_builtin
#define __has_builtin(x) defined(__GNUC__)
#endif

#if __has_builtin(__builtin___snprintf_chk)
#define __snprintf_chk_func(str, len, flag, ...) \
	__builtin___snprintf_chk (str, len, flag, __darwin_obsz(str), __VA_ARGS__)
#endif

#if __has_builtin(__builtin___vsnprintf_chk)
#define __vsnprintf_chk_func(str, len, flag, format, ap) \
	__builtin___vsnprintf_chk (str, len, flag, __darwin_obsz(str), format, ap)
#endif


#if __has_builtin(__builtin___sprintf_chk)
#define __sprintf_chk_func(str, flag, ...) \
	__builtin___sprintf_chk (str, flag, __darwin_obsz(str), __VA_ARGS__)
#endif

#if __has_builtin(__builtin___vsprintf_chk)
#define __vsprintf_chk_func(str, flag, format, ap) \
	__builtin___vsprintf_chk (str, flag, __darwin_obsz(str), format, ap)
#endif


#ifdef __undef__has_builtin
#undef __undef__has_builtin
#undef __has_builtin
#endif

#endif

/* sprintf, vsprintf, snprintf, vsnprintf */

#ifdef __sprintf_chk_func
#undef sprintf
#define sprintf(str, ...) __sprintf_chk_func (str, 0, __VA_ARGS__)
#endif

#if __DARWIN_C_LEVEL >= 200112L

#ifdef __vsprintf_chk_func
#undef vsprintf
#define vsprintf(str, ...) __vsprintf_chk_func (str, 0, __VA_ARGS__)
#endif

#ifdef __snprintf_chk_func
#undef snprintf
#define snprintf(str, len, ...) __snprintf_chk_func (str, len, 0, __VA_ARGS__)
#endif

#ifdef __vsnprintf_chk_func
#undef vsnprintf
#define vsnprintf(str, len, ...) __vsnprintf_chk_func (str, len, 0, __VA_ARGS__)
#endif

#endif

#endif /* _USE_FORTIFY_LEVEL > 0 */
#endif /* _SECURE__STDIO_H_ */
