/*
 * Copyright (c) 2017, 2023 Apple Inc. All rights reserved.
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

#ifndef __STRINGS_H_
# error "Never use <secure/_strings.h> directly; include <strings.h> instead."
#endif

#ifndef _SECURE__STRINGS_H_
#define _SECURE__STRINGS_H_

#include <sys/cdefs.h>
#include <Availability.h>
#include <secure/_common.h>

#if _USE_FORTIFY_LEVEL > 0

/* bcopy and bzero */

/* Removed in Issue 7 */
#if !defined(_POSIX_C_SOURCE) || _POSIX_C_SOURCE < 200809L

#ifdef __LIBC_STAGED_BOUNDS_SAFETY_ATTRIBUTES

static inline void
__bcopy_ptrcheck(const void *_LIBC_SIZE(__n) __src, void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, size_t __n) {
	memmove(__dst, __src, __n);
}

static inline void
__bzero_ptrcheck(void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, size_t __n) {
	memset(__dst, 0, __n);
}

#define __bcopy_chk_func __bcopy_ptrcheck
#define __bzero_chk_func __bzero_ptrcheck

#else

#ifndef __has_builtin
#define __undef__has_builtin
#define __has_builtin(x) defined(__GNUC__)
#endif

#if __has_builtin(__builtin___memmove_chk)
#define __bcopy_chk_func(src, dst, ...) \
	__builtin___memmove_chk(dst, src, __VA_ARGS__, __darwin_obsz0 (dst))
#endif

#if __has_builtin(__builtin___memset_chk)
#define __bzero_chk_func(dst, ...) \
	__builtin___memset_chk(dst, 0, __VA_ARGS__, __darwin_obsz0 (dst))
#endif

#ifdef __undef__has_builtin
#undef __undef__has_builtin
#undef __has_builtin
#endif

#endif

#ifdef __bcopy_chk_func
#undef bcopy
/* void	bcopy(const void *src, void *dst, size_t len) */
#define bcopy(...) __bcopy_chk_func (__VA_ARGS__)
#endif

#ifdef __bzero_chk_func
#undef bzero
/* void	bzero(void *s, size_t n) */
#define bzero(...) __bzero_chk_func (__VA_ARGS__)
#endif

#endif

#endif /* _USE_FORTIFY_LEVEL > 0 */
#endif /* _SECURE__STRINGS_H_ */
