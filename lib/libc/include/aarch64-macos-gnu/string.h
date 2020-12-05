/*
 * Copyright (c) 2000, 2007, 2010 Apple Inc. All rights reserved.
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
/*-
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)string.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _STRING_H_
#define	_STRING_H_

#include <_types.h>
#include <sys/cdefs.h>
#include <Availability.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_null.h>

/* ANSI-C */

__BEGIN_DECLS
void	*memchr(const void *__s, int __c, size_t __n);
int	 memcmp(const void *__s1, const void *__s2, size_t __n);
void	*memcpy(void *__dst, const void *__src, size_t __n);
void	*memmove(void *__dst, const void *__src, size_t __len);
void	*memset(void *__b, int __c, size_t __len);
char	*strcat(char *__s1, const char *__s2);
char	*strchr(const char *__s, int __c);
int	 strcmp(const char *__s1, const char *__s2);
int	 strcoll(const char *__s1, const char *__s2);
char	*strcpy(char *__dst, const char *__src);
size_t	 strcspn(const char *__s, const char *__charset);
char	*strerror(int __errnum) __DARWIN_ALIAS(strerror);
size_t	 strlen(const char *__s);
char	*strncat(char *__s1, const char *__s2, size_t __n);
int	 strncmp(const char *__s1, const char *__s2, size_t __n);
char	*strncpy(char *__dst, const char *__src, size_t __n);
char	*strpbrk(const char *__s, const char *__charset);
char	*strrchr(const char *__s, int __c);
size_t	 strspn(const char *__s, const char *__charset);
char	*strstr(const char *__big, const char *__little);
char	*strtok(char *__str, const char *__sep);
size_t	 strxfrm(char *__s1, const char *__s2, size_t __n);
__END_DECLS



/* Additional functionality provided by:
 * POSIX.1c-1995,
 * POSIX.1i-1995,
 * and the omnibus ISO/IEC 9945-1: 1996
 */

#if __DARWIN_C_LEVEL >= 199506L
__BEGIN_DECLS
char	*strtok_r(char *__str, const char *__sep, char **__lasts);
__END_DECLS
#endif /* __DARWIN_C_LEVEL >= 199506L */



/* Additional functionality provided by:
 * POSIX.1-2001
 */

#if __DARWIN_C_LEVEL >= 200112L
__BEGIN_DECLS
int	 strerror_r(int __errnum, char *__strerrbuf, size_t __buflen);
char	*strdup(const char *__s1);
void	*memccpy(void *__dst, const void *__src, int __c, size_t __n);
__END_DECLS
#endif /* __DARWIN_C_LEVEL >= 200112L */



/* Additional functionality provided by:
 * POSIX.1-2008
 */

#if __DARWIN_C_LEVEL >= 200809L
__BEGIN_DECLS
char	*stpcpy(char *__dst, const char *__src);
char    *stpncpy(char *__dst, const char *__src, size_t __n) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
char	*strndup(const char *__s1, size_t __n) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
size_t   strnlen(const char *__s1, size_t __n) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
char	*strsignal(int __sig);
__END_DECLS
#endif /* __DARWIN_C_LEVEL >= 200809L */

/* C11 Annex K */

#if defined(__STDC_WANT_LIB_EXT1__) && __STDC_WANT_LIB_EXT1__ >= 1
#include <sys/_types/_rsize_t.h>
#include <sys/_types/_errno_t.h>

__BEGIN_DECLS
errno_t	memset_s(void *__s, rsize_t __smax, int __c, rsize_t __n) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
__END_DECLS
#endif

/* Darwin extensions */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#include <sys/_types/_ssize_t.h>

__BEGIN_DECLS
void	*memmem(const void *__big, size_t __big_len, const void *__little, size_t __little_len) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
void     memset_pattern4(void *__b, const void *__pattern4, size_t __len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_0);
void     memset_pattern8(void *__b, const void *__pattern8, size_t __len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_0);
void     memset_pattern16(void *__b, const void *__pattern16, size_t __len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_0);

char	*strcasestr(const char *__big, const char *__little);
char	*strnstr(const char *__big, const char *__little, size_t __len);
size_t	 strlcat(char *__dst, const char *__source, size_t __size);
size_t	 strlcpy(char *__dst, const char *__source, size_t __size);
void	 strmode(int __mode, char *__bp);
char	*strsep(char **__stringp, const char *__delim);

/* SUS places swab() in unistd.h.  It is listed here for source compatibility */
void	 swab(const void * __restrict, void * __restrict, ssize_t);

__OSX_AVAILABLE(10.12.1) __IOS_AVAILABLE(10.1)
__TVOS_AVAILABLE(10.0.1) __WATCHOS_AVAILABLE(3.1)
int	timingsafe_bcmp(const void *__b1, const void *__b2, size_t __len);

__OSX_AVAILABLE(11.0) __IOS_AVAILABLE(14.0)
__TVOS_AVAILABLE(14.0) __WATCHOS_AVAILABLE(7.0)
int 	 strsignal_r(int __sig, char *__strsignalbuf, size_t __buflen);
__END_DECLS

/* Some functions historically defined in string.h were placed in strings.h
 * by SUS.  We are using "strings.h" instead of <strings.h> to avoid an issue
 * where /Developer/Headers/FlatCarbon/Strings.h could be included instead on
 * case-insensitive file systems.
 */
#include "strings.h"
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */


#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_string.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#if defined (__GNUC__) && _FORTIFY_SOURCE > 0 && !defined (__cplusplus)
/* Security checking functions.  */
#include <secure/_string.h>
#endif

#endif /* _STRING_H_ */
