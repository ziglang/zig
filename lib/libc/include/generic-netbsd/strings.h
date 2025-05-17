/*	$NetBSD: strings.h,v 1.18 2011/08/22 01:24:15 dholland Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _STRINGS_H_
#define _STRINGS_H_

#include <machine/ansi.h>
#include <sys/featuretest.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#if defined(_NETBSD_SOURCE)
#include <sys/null.h>
#endif

#include <sys/cdefs.h>

#include <machine/int_types.h>

__BEGIN_DECLS
int	 bcmp(const void *, const void *, size_t);
void	 bcopy(const void *, void *, size_t);
void	 bzero(void *, size_t);
int	 ffs(int);
char	*index(const char *, int);
unsigned int	popcount(unsigned int) __constfunc;
unsigned int	popcountl(unsigned long) __constfunc;
unsigned int	popcountll(unsigned long long) __constfunc;
unsigned int	popcount32(__uint32_t) __constfunc;
unsigned int	popcount64(__uint64_t) __constfunc;
char	*rindex(const char *, int);
int	 strcasecmp(const char *, const char *);
int	 strncasecmp(const char *, const char *, size_t);
__END_DECLS

#if defined(_NETBSD_SOURCE)
#include <string.h>
#endif

#if _FORTIFY_SOURCE > 0
#include <ssp/strings.h>
#endif
#endif /* !defined(_STRINGS_H_) */