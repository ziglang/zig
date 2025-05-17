/*	$NetBSD: cdbr.h,v 1.1 2013/12/11 01:24:08 joerg Exp $	*/
/*-
 * Copyright (c) 2010 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Joerg Sonnenberger.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_CDBR_H
#define	_CDBR_H

#include <sys/cdefs.h>
#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/types.h>
#else
#include <inttypes.h>
#include <stddef.h>
#endif

#define	CDBR_DEFAULT	0

struct cdbr;

__BEGIN_DECLS

#if !defined(_KERNEL) && !defined(_STANDALONE)
struct cdbr	*cdbr_open(const char *, int);
#endif
struct cdbr	*cdbr_open_mem(void *, size_t, int,
    void (*)(void *, void *, size_t), void *);
uint32_t	 cdbr_entries(struct cdbr *);
int		 cdbr_get(struct cdbr *, uint32_t, const void **, size_t *);
int		 cdbr_find(struct cdbr *, const void *, size_t,
    const void **, size_t *);
void		 cdbr_close(struct cdbr *);

__END_DECLS

#endif /* _CDBR_H */