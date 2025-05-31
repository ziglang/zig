/*	$NetBSD: localcount.h,v 1.5 2017/11/17 09:26:36 ozaki-r Exp $	*/

/*-
 * Copyright (c) 2016 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Taylor R. Campbell.
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

#ifndef	_SYS_LOCALCOUNT_H
#define	_SYS_LOCALCOUNT_H

#ifndef _KERNEL
#error <sys/localcount.h> is for kernel consumers only.
#endif

#include <sys/types.h>

struct kcondvar;
struct kmutex;
struct percpu;

struct localcount {
	int64_t			*lc_totalp;
	struct percpu		*lc_percpu; /* int64_t */
	volatile uint32_t	lc_refcnt; /* only for debugging */
};

void	localcount_init(struct localcount *);
void	localcount_drain(struct localcount *, struct kcondvar *,
	    struct kmutex *);
void	localcount_fini(struct localcount *);
void	localcount_acquire(struct localcount *);
void	localcount_release(struct localcount *, struct kcondvar *,
	    struct kmutex *);

uint32_t
	localcount_debug_refcnt(const struct localcount *);

#endif	/* _SYS_LOCALCOUNT_H */