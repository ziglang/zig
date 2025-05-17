/*	$NetBSD: stdarg.h,v 1.6 2022/10/08 15:48:01 christos Exp $	*/

/*-
 * Copyright (c) 1991, 1993
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
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)stdarg.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _SYS_STDARG_H_
#define	_SYS_STDARG_H_

#include <sys/cdefs.h>
#include <sys/ansi.h>
#include <sys/featuretest.h>

#ifdef __lint__
#define __builtin_next_arg(t)		((t) ? 0 : 0)
#define	__builtin_va_start(a, l)	((a) = (va_list)(void *)&(l))
#define	__builtin_va_arg(a, t)		((a) ? (t) 0 : (t) 0)
#define	__builtin_va_end(a)		__nothing
#define	__builtin_va_copy(d, s)		((d) = (s))
#elif !(__GNUC_PREREQ__(4, 5) || \
    (__GNUC_PREREQ__(4, 4) && __GNUC_PATCHLEVEL__ > 2) || defined(__clang__))
#define __builtin_va_start(ap, last)    __builtin_stdarg_start((ap), (last))
#endif

#ifndef __VA_LIST_DECLARED
typedef __va_list va_list;
#define __VA_LIST_DECLARED
#endif

#define	va_start(ap, last)	__builtin_va_start((ap), (last))
#define	va_arg			__builtin_va_arg
#define	va_end(ap)		__builtin_va_end(ap)
#define	__va_copy(dest, src)	__builtin_va_copy((dest), (src))

#if !defined(_ANSI_SOURCE) && \
    (defined(_ISOC99_SOURCE) || (__STDC_VERSION__ - 0) >= 199901L || \
     defined(_NETBSD_SOURCE))
#define	va_copy(dest, src)	__va_copy((dest), (src))
#endif

#endif /* !_SYS_STDARG_H_ */