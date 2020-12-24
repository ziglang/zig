/*
 * Copyright (c) 2005, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef _XLOCALE__STDIO_H_
#define _XLOCALE__STDIO_H_

#include <_stdio.h>
#include <_xlocale.h>

__BEGIN_DECLS

int	 fprintf_l(FILE * __restrict, locale_t __restrict, const char * __restrict, ...)
        __printflike(3, 4);
int	 fscanf_l(FILE * __restrict, locale_t __restrict, const char * __restrict, ...)
        __scanflike(3, 4);
int	 printf_l(locale_t __restrict, const char * __restrict, ...)
        __printflike(2, 3);
int	 scanf_l(locale_t __restrict, const char * __restrict, ...)
        __scanflike(2, 3);
int	 sprintf_l(char * __restrict, locale_t __restrict, const char * __restrict, ...)
        __printflike(3, 4) __swift_unavailable("Use snprintf_l instead.");
int	 sscanf_l(const char * __restrict, locale_t __restrict, const char * __restrict, ...) 
        __scanflike(3, 4);
int	 vfprintf_l(FILE * __restrict, locale_t __restrict, const char * __restrict, va_list)
        __printflike(3, 0);
int	 vprintf_l(locale_t __restrict, const char * __restrict, va_list)
        __printflike(2, 0);
int	 vsprintf_l(char * __restrict, locale_t __restrict, const char * __restrict, va_list)
        __printflike(3, 0) __swift_unavailable("Use vsnprintf_l instead.");

#if __DARWIN_C_LEVEL >= 200112L || defined(__cplusplus)
int	 snprintf_l(char * __restrict, size_t, locale_t __restrict, const char * __restrict, ...)
        __printflike(4, 5);
int	 vfscanf_l(FILE * __restrict, locale_t __restrict, const char * __restrict, va_list)
        __scanflike(3, 0);
int	 vscanf_l(locale_t __restrict, const char * __restrict, va_list)
        __scanflike(2, 0);
int	 vsnprintf_l(char * __restrict, size_t, locale_t __restrict, const char * __restrict, va_list)
        __printflike(4, 0);
int	 vsscanf_l(const char * __restrict, locale_t __restrict, const char * __restrict, va_list)
        __scanflike(3, 0);
#endif

#if __DARWIN_C_LEVEL >= 200809L || defined(__cplusplus)
int	 dprintf_l(int, locale_t __restrict, const char * __restrict, ...)
        __printflike(3, 4) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int	 vdprintf_l(int, locale_t __restrict, const char * __restrict, va_list)
        __printflike(3, 0) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
#endif


#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL || defined(__cplusplus)
int	 asprintf_l(char ** __restrict, locale_t __restrict, const char * __restrict, ...)
        __printflike(3, 4);
int	 vasprintf_l(char ** __restrict, locale_t __restrict, const char * __restrict, va_list)
        __printflike(3, 0);
#endif

__END_DECLS


#endif /* _XLOCALE__STDIO_H_ */