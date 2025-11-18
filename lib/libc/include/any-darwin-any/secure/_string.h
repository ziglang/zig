/*
 * Copyright (c) 2007,2017,2023 Apple Inc. All rights reserved.
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

#ifndef _STRING_H_
# error "Never use <secure/_string.h> directly; include <string.h> instead."
#endif

#ifndef _SECURE__STRING_H_
#define _SECURE__STRING_H_

#include <sys/cdefs.h>
#include <Availability.h>
#include <secure/_common.h>

#if _USE_FORTIFY_LEVEL > 0

#ifdef __LIBC_STAGED_BOUNDS_SAFETY_ATTRIBUTES

#if __has_builtin(__builtin___memcpy_chk)
static inline void *_LIBC_SIZE(__n)
__memcpy_ptrchk(void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, const void *_LIBC_SIZE(__n) __src, size_t __n) {
	return _LIBC_FORGE_PTR(__builtin___memcpy_chk(__dst, __src, __n, __darwin_obsz0(__dst)), __n);
}
#define __memcpy_chk_func __memcpy_ptrchk
#endif

#if __has_builtin(__builtin___memmove_chk)
static inline void *_LIBC_SIZE(__n)
__memmove_ptrchk(void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, const void *_LIBC_SIZE(__n) __src, size_t __n) {
	return _LIBC_FORGE_PTR(__builtin___memmove_chk(__dst, __src, __n, __darwin_obsz0(__dst)), __n);
}
#define __memmove_chk_func __memmove_ptrchk
#endif

#if __has_builtin(__builtin___memset_chk)
static inline void *_LIBC_SIZE(__n)
__memset_ptrchk(void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, int __c, size_t __n) {
	return _LIBC_FORGE_PTR(__builtin___memset_chk(__dst, __c, __n, __darwin_obsz0(__dst)), __n);
}
#define __memset_chk_func __memset_ptrchk
#endif

#undef __stpncpy_chk_func /* stpncpy unavailable */
#undef __strncpy_chk_func /* strncpy unavailable */

#if __has_builtin(__builtin___strlcpy_chk)
static inline size_t
__strlcpy_ptrchk(char *const _LIBC_SIZE(__n) __darwin_pass_obsz __dst, const char *__src, size_t __n) {
	return __builtin___strlcpy_chk(__dst, __src, __n, __darwin_obsz(__dst));
}
#define __strlcpy_chk_func __strlcpy_ptrchk
#endif

#if __has_builtin(__builtin___strlcat_chk)
static inline size_t
__strlcat_ptrchk(char *const _LIBC_SIZE(__n) __darwin_pass_obsz __dst, const char *__src, size_t __n) {
	return __builtin___strlcat_chk(__dst, __src, __n, __darwin_obsz(__dst));
}
#define __strlcat_chk_func __strlcat_ptrchk
#endif

#if __has_builtin(__builtin___memccpy_chk)
static inline void *_LIBC_SIZE(__n)
__memccpy_ptrchk(void *const _LIBC_SIZE(__n) __darwin_pass_obsz0 __dst, const void *_LIBC_SIZE(__n) __src, int __c, size_t __n) {
	return _LIBC_FORGE_PTR(__builtin___memccpy_chk(__dst, __src, __c, __n, __darwin_obsz0(__dst)), __n);
}
#define __memccpy_chk_func __memccpy_ptrchk
#endif

#undef __strcpy_chk_func /* strcpy unavailable */
#undef __stpcpy_chk_func /* stpcpy unavailable */
#undef __strcat_chk_func /* strcat unavailable */
#undef __strncat_chk_func /* strncat unavailable */

#else /* __LIBC_STAGED_BOUNDS_SAFETY_ATTRIBUTES */

#define __is_modern_darwin(ios, macos) \
	(__IPHONE_OS_VERSION_MIN_REQUIRED >= (ios) || \
	 __MAC_OS_X_VERSION_MIN_REQUIRED >= (macos) || \
	 defined(__DRIVERKIT_VERSION_MIN_REQUIRED))

/* __is_gcc(gcc_major, gcc_minor)
 * Special values:
 * 10.0 means "test should always fail when __has_builtin isn't supported"
   (because gcc got __has_builtin in version 10.0); this is used for builtins
   that gcc did not support yet at the time __has_builtin was introduced, so
   there is no point checking the compiler version.
 * 0.0 means that we did not research when gcc started supporting this builtin,
   but it's believed to have been the case at least since gcc 4.0, which came
   out in 2005. (Hello from 2025! What year is it now? Can't believe we're still
   using C!)
 */
#define __is_gcc(major, minor) \
	(__GNUC__ > (gcc_major) || \
	(__GNUC__ == (gcc_major) && __GNUC_MINOR__ >= (gcc_minor)))

#ifdef __has_builtin
#define __supports_builtin(builtin, gcc_major, gcc_minor) \
	__has_builtin(builtin)
#else
#define __supports_builtin(builtin, gcc_major, gcc_minor) __is_gcc(gcc_major, gcc_minor)
#endif


#if __supports_builtin(__builtin___memcpy_chk, 0, 0)
#define __memcpy_chk_func(dest, ...) \
		__builtin___memcpy_chk (dest, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#if __supports_builtin(__builtin___memmove_chk, 0, 0)
#define __memmove_chk_func(dest, ...) \
		__builtin___memmove_chk (dest, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#if __supports_builtin(__builtin___memset_chk, 0, 0)
#define __memset_chk_func(dest, ...) \
		__builtin___memset_chk (dest, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#if __supports_builtin(__builtin___stpncpy_chk, 4, 7)
#define __stpncpy_chk_func(dest, ...) \
		__builtin___stpncpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __supports_builtin(__builtin___strncpy_chk, 0, 0)
#define __strncpy_chk_func(dest, ...) \
		__builtin___strncpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __is_modern_darwin(70000, 1090)

#if __supports_builtin(__builtin___strlcpy_chk, 0, 0)
#define __strlcpy_chk_func(dest, ...) \
		__builtin___strlcpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __supports_builtin(__builtin___strlcat_chk, 0, 0)
#define __strlcat_chk_func(dest, ...) \
		__builtin___strlcat_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __supports_builtin(__builtin___memccpy_chk, 10, 0)
#define __memccpy_chk_func(dest, ...) \
	__builtin___memccpy_chk (dest, __VA_ARGS__, __darwin_obsz0 (dest))
#endif

#endif /* __is_modern_darwin(70000, 1090) */


#if __supports_builtin(__builtin___strcpy_chk, 0, 0)
#define __strcpy_chk_func(dest, ...) \
		__builtin___strcpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __supports_builtin(__builtin___stpcpy_chk, 0, 0)
#define __stpcpy_chk_func(dest, ...) \
		__builtin___stpcpy_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if __supports_builtin(__builtin___strcat_chk, 0, 0)
#define __strcat_chk_func(dest, ...) \
		__builtin___strcat_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif

#if ! (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 32000)
#if __supports_builtin(__builtin___strncat_chk, 0, 0)
#define __strncat_chk_func(dest, ...) \
		__builtin___strncat_chk (dest, __VA_ARGS__, __darwin_obsz (dest))
#endif
#endif


#undef __supports_builtin
#undef __is_gcc

#endif /* defined(__has_ptrcheck) && __has_ptrcheck */

#undef __is_modern_darwin

/* memccpy, memcpy, mempcpy, memmove, memset, strcpy, strlcpy, stpcpy,
   strncpy, stpncpy, strcat, strlcat, and strncat */

/* The use of .../__VA_ARGS__ is load-bearing. If the macros take fixed
 * arguments, they are unable to themselves accept macros that expand to
 * multiple arguments, like this:
 *  #define memcpy(a, b, c) ...
 *  #define FOO(data) get_bytes(data), get_length(data)
 *  memcpy(bar, FOO(d));
 * This will fail because the preprocessor only sees two arguments on the first
 * expansion of memcpy, when 3 are required.
 * This is also required to support syntaxes that embed commas. The preprocessor
 * recognizes parentheses for the isolation of arguments but not brackets. This
 * expands to 3 arguments:
 *  strcpy(destination, [NSString stringWithFormat:@"%i", 4].UTF8String);
 *         ^            ^                                 ^
 *         |destination |                                 |
 *                      |[NSString stringWithFormat:@"%i" |
 *							  |4].UTF8String
 * This expands to 4 arguments:
 *  memcpy(destination, (uint8_t[]) { 1, 2 }, 2);
 *         ^            ^                ^    ^
 * To work correctly under these hostile circumstances, chk_func macros
 * need to expand to a bare identifier (like #define memcpy_chk_func __memcpy)
 * or to a macro that also takes variadic arguments.
 */

#ifdef __memccpy_chk_func
#undef memccpy
#define memccpy(...) __memccpy_chk_func (__VA_ARGS__)
#endif

#ifdef __memcpy_chk_func
#undef memcpy
#define memcpy(...) __memcpy_chk_func (__VA_ARGS__)
#endif

#ifdef __memmove_chk_func
#undef memmove
#define memmove(...) __memmove_chk_func (__VA_ARGS__)
#endif

#ifdef __memset_chk_func
#undef memset
#define memset(...) __memset_chk_func (__VA_ARGS__)
#endif

#if defined(__strcpy_chk_func)
#undef strcpy
#define strcpy(...) __strcpy_chk_func (__VA_ARGS__)
#endif

#if defined(__strcat_chk_func)
#undef strcat
#define strcat(...) __strcat_chk_func (__VA_ARGS__)
#endif

#if defined(__strncpy_chk_func)
#undef strncpy
#define strncpy(...) __strncpy_chk_func (__VA_ARGS__)
#endif

#if defined(__strncat_chk_func)
#undef strncat
#define strncat(...) __strncat_chk_func (__VA_ARGS__)
#endif

#if __DARWIN_C_LEVEL >= 200809L

#if defined(__stpcpy_chk_func)
#undef stpcpy
#define stpcpy(...) __stpcpy_chk_func (__VA_ARGS__)
#endif

#if defined(__stpncpy_chk_func)
#undef stpncpy
#define stpncpy(...) __stpncpy_chk_func (__VA_ARGS__)
#endif

#endif /* __DARWIN_C_LEVEL >= 200809L */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#if defined(__strlcpy_chk_func)
#undef strlcpy
#define strlcpy(...) __strlcpy_chk_func (__VA_ARGS__)
#endif

#if defined(__strlcat_chk_func)
#undef strlcat
#define strlcat(...) __strlcat_chk_func (__VA_ARGS__)
#endif
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#endif /* _USE_FORTIFY_LEVEL > 0 */

#endif /* _SECURE__STRING_H_ */
