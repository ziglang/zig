/*	$NetBSD: cachectl.h,v 1.11 2020/07/26 08:08:41 simonb Exp $	*/

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jonathan Stone.
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

#ifndef _MIPS_CACHECTL_H_
#define	_MIPS_CACHECTL_H_

#include <sys/cdefs.h>

__BEGIN_DECLS
/*
 * invalidate a range of addresses from the cache.
 */
int  _cacheflush(void *, size_t, int);
int  cacheflush(void *, size_t, int);

					/* cacheflush() flags: */
#define	ICACHE	0x01			/* invalidate I-cache */
#define	DCACHE	0x02			/* writeback and invalidate D-cache */
#define	BCACHE	(ICACHE|DCACHE)		/* invalidate both caches, as above */


int  cachectl(void *, size_t, int);

					/* cachectl() cache operations: */
#define	CACHEABLE       0x00		/* make page(s) cacheable */
#define	UNCACHEABLE     0x01		/* make page(s) uncacheable */

__END_DECLS

#ifdef _KERNEL
int mips_user_cachectl(struct proc *, vaddr_t, size_t, int);
int mips_user_cacheflush(struct proc *, vaddr_t, size_t, int);
#endif
#endif /* _MIPS_CACHECTL_H_ */