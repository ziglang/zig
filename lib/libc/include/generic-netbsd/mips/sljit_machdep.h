/*	$NetBSD: sljit_machdep.h,v 1.2 2020/07/26 08:08:41 simonb Exp $	*/

/*-
 * Copyright (c) 2012,2014 The NetBSD Foundation, Inc.
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

#ifndef _MIPS_SLJITARCH_H
#define	_MIPS_SLJITARCH_H

#ifdef _LP64
#define	SLJIT_CONFIG_MIPS_64 1
#else
#define	SLJIT_CONFIG_MIPS_32 1
#endif

#include <sys/types.h>

#ifdef _KERNEL
#include <mips/cache.h>

#define	SLJIT_CACHE_FLUSH(from, to) mips_icache_sync_range( \
	(vaddr_t)(from), (vsize_t)((const char *)(to) - (const char *)(from)))
#else
#include <mips/cachectl.h>

#define	SLJIT_CACHE_FLUSH(from, to) \
	(void)_cacheflush((void*)(from), (size_t)((to) - (from)), ICACHE)
#endif

#endif