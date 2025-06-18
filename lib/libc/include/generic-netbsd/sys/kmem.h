/*	$NetBSD: kmem.h,v 1.12 2021/01/24 17:29:11 thorpej Exp $	*/

/*-
 * Copyright (c)2006 YAMAMOTO Takashi,
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
 */

#ifndef _SYS_KMEM_H_
#define	_SYS_KMEM_H_

#include <sys/types.h>

typedef unsigned int km_flag_t;

void	kmem_init(void);
size_t	kmem_roundup_size(size_t);

void *	kmem_alloc(size_t, km_flag_t);
void *	kmem_zalloc(size_t, km_flag_t);
void	kmem_free(void *, size_t);

void *	kmem_intr_alloc(size_t, km_flag_t);
void *	kmem_intr_zalloc(size_t, km_flag_t);
void	kmem_intr_free(void *, size_t);

char *	kmem_asprintf(const char *, ...) __printflike(1, 2);

char *	kmem_strdupsize(const char *, size_t *, km_flag_t);
#define kmem_strdup(s, f)	kmem_strdupsize((s), NULL, (f))
char *	kmem_strndup(const char *, size_t, km_flag_t);
void	kmem_strfree(char *);

void *	kmem_tmpbuf_alloc(size_t, void *, size_t, km_flag_t);
void	kmem_tmpbuf_free(void *, size_t, void *);

/*
 * km_flag_t values:
 */
#define	KM_SLEEP	0x00000001	/* can sleep */
#define	KM_NOSLEEP	0x00000002	/* don't sleep */

#endif /* !_SYS_KMEM_H_ */