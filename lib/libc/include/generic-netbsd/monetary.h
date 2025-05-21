/*	$NetBSD: monetary.h,v 1.4 2019/12/08 02:15:02 kre Exp $	*/

/*-
 * Copyright (c) 2001 Alexey Zelkin <phantom@FreeBSD.org>
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: src/include/monetary.h,v 1.7 2002/09/20 08:22:48 mike Exp $
 */

#ifndef _MONETARY_H_
#define	_MONETARY_H_

#include <sys/cdefs.h>
#include <machine/ansi.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#ifdef	_BSD_SSIZE_T_
typedef	_BSD_SSIZE_T_	ssize_t;
#undef	_BSD_SSIZE_T_
#endif

#if defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
__BEGIN_DECLS
ssize_t	strfmon_l(char * __restrict, size_t, locale_t, const char * __restrict, ...)
    __attribute__((__format__(__strfmon__, 4, 5)));
__END_DECLS
#endif

__BEGIN_DECLS
ssize_t	strfmon(char * __restrict, size_t, const char * __restrict, ...)
    __attribute__((__format__(__strfmon__, 3, 4)));
__END_DECLS

#endif /* !_MONETARY_H_ */