/*	$NetBSD: iconv.h,v 1.7 2019/10/24 18:17:59 kamil Exp $	*/

/*-
 * Copyright (c)2003 Citrus Project,
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
 */

#ifndef _ICONV_H_
#define _ICONV_H_

#include <sys/cdefs.h>
#include <machine/ansi.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

struct __tag_iconv_t;
typedef	struct __tag_iconv_t	*iconv_t;

__BEGIN_DECLS
iconv_t	iconv_open(const char *, const char *);
size_t	iconv(iconv_t, char ** __restrict,
		     size_t * __restrict, char ** __restrict,
		     size_t * __restrict);
int	iconv_close(iconv_t);
/*
 * non-portable interfaces for iconv
 */
int	__iconv_get_list(char ***, size_t *);
void	__iconv_free_list(char **, size_t);
size_t	__iconv(iconv_t, char **, size_t *, char **,
		     size_t *, __uint32_t, size_t *);
#define __ICONV_F_HIDE_INVALID	0x0001
__END_DECLS

#endif /* !_ICONV_H_ */