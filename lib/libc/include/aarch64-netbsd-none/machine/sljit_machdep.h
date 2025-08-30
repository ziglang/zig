/*	$NetBSD: sljit_machdep.h,v 1.3.18.2 2024/05/11 14:08:32 martin Exp $	*/

/*-
 * Copyright (c) 2014 Alexander Nasonov.
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

#ifndef _AARCH64_SLJITARCH_H
#define _AARCH64_SLJITARCH_H

#ifndef __aarch64__		/* compat32 */

#include <arm/sljit_machdep.h>

#else  /* __aarch64__ */

#include <sys/cdefs.h>

#ifdef _KERNEL
#include <machine/types.h>

#include <arm/cpufunc.h>
#else
#include <stddef.h>
#include <stdint.h>
#include <aarch64/sysarch.h>
#endif

#define SLJIT_CONFIG_ARM_64 1

#ifdef _HARDKERNEL
/*
 * XXX Currently sys/rump/include/machine/cpu.h doesn't have
 * ci_cpufuncs for cpu_icache_sync_range, so we do this only for
 * non-rump kernels for now.
 */
#define SLJIT_CACHE_FLUSH(from, to) \
	cpu_icache_sync_range((vaddr_t)(from), (vsize_t)((to) - (from)))
#else
#define SLJIT_CACHE_FLUSH(from, to) \
	(void)__builtin___clear_cache((char *)(from), (char *)(to))
#endif

#endif	/* __aarch64__ (vs compat32) */

#endif	/* _AARCH64_SLJITARCH_H */