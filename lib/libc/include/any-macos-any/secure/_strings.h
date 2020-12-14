/*
 * Copyright (c) 2017 Apple Inc. All rights reserved.
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

#ifndef _STRINGS_H_
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

#if __has_builtin(__builtin___memmove_chk) || defined(__GNUC__)
#undef bcopy
/* void	bcopy(const void *src, void *dst, size_t len) */
#define bcopy(src, dest, ...) \
		__builtin___memmove_chk (dest, src, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#if __has_builtin(__builtin___memset_chk) || defined(__GNUC__)
#undef bzero
/* void	bzero(void *s, size_t n) */
#define bzero(dest, ...) \
		__builtin___memset_chk (dest, 0, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#endif

#endif /* _USE_FORTIFY_LEVEL > 0 */
#endif /* _SECURE__STRINGS_H_ */