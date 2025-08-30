/*	$NetBSD: malloc.h,v 1.8 2019/03/12 15:11:13 christos Exp $	*/

/*-
 * Copyright (c) 2019 The NetBSD Foundation, Inc.
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

#ifndef _MALLOC_H_
#define _MALLOC_H_

#include <stdlib.h>

__BEGIN_DECLS

void *mallocx(size_t, int);
void *rallocx(void *, size_t, int);
size_t xallocx(void *, size_t, size_t, int);
size_t sallocx(const void *, int);
void dallocx(void *, int);
void sdallocx(void *, size_t, int);
size_t nallocx(size_t, int);

int mallctl(const char *, void *, size_t *, void *, size_t);
int mallctlnametomib(const char *, size_t *, size_t *);
int mallctlbymib(const size_t *, size_t, void *, size_t *, void *, size_t);

void malloc_stats_print(void (*)(void *, const char *), void *, const char *);

size_t malloc_usable_size(const void *);

void (*malloc_message_get(void))(void *, const char *);
void malloc_message_set(void (*)(void *, const char *));

const char *malloc_conf_get(void);
void malloc_conf_set(const char *);

__END_DECLS

#endif /* _MALLOC_H_ */