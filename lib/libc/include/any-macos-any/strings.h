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
 *	@(#)strings.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _STRINGS_H_
#define _STRINGS_H_

#include <_types.h>

#include <sys/cdefs.h>
#include <Availability.h>
#include <sys/_types/_size_t.h>

__BEGIN_DECLS
/* Removed in Issue 7 */
#if !defined(_POSIX_C_SOURCE) || _POSIX_C_SOURCE < 200809L
int	 bcmp(const void *, const void *, size_t) __POSIX_C_DEPRECATED(200112L);
void	 bcopy(const void *, void *, size_t) __POSIX_C_DEPRECATED(200112L);
void	 bzero(void *, size_t) __POSIX_C_DEPRECATED(200112L);
char	*index(const char *, int) __POSIX_C_DEPRECATED(200112L);
char	*rindex(const char *, int) __POSIX_C_DEPRECATED(200112L);
#endif

int	 ffs(int);
int	 strcasecmp(const char *, const char *);
int	 strncasecmp(const char *, const char *, size_t);
__END_DECLS

/* Darwin extensions */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
__BEGIN_DECLS
int	 ffsl(long) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int	 ffsll(long long) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
int	 fls(int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int	 flsl(long) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int	 flsll(long long) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
__END_DECLS

#include <string.h>
#endif

#if defined (__GNUC__) && _FORTIFY_SOURCE > 0 && !defined (__cplusplus)
/* Security checking functions.  */
#include <secure/_strings.h>
#endif

#endif  /* _STRINGS_H_ */