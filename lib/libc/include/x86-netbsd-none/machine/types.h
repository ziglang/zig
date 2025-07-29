/*	$NetBSD: types.h,v 1.93 2021/04/01 04:35:46 simonb Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
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
 *	@(#)types.h	7.5 (Berkeley) 3/9/91
 */

#ifndef	_I386_MACHTYPES_H_
#define	_I386_MACHTYPES_H_

#ifdef _KERNEL_OPT
#include "opt_xen.h"
#endif
#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/int_types.h>

typedef int			__register_t;
typedef unsigned long		__vaddr_t;	/* segments.h */
typedef unsigned char		__cpu_simple_lock_nv_t;

#if defined(_KERNEL)
typedef struct label_t {
	int val[6];
} label_t;
#endif

#if defined(_KERNEL)
/*
 * XXX JYM for now, in kernel paddr_t can be 32 or 64 bits, depending
 * on PAE. Revisit when paddr_t becomes 64 bits for !PAE systems.
 */
#ifdef PAE
typedef __uint64_t	paddr_t;
typedef __uint64_t	psize_t;
#define	PRIxPADDR	"llx"
#define	PRIxPSIZE	"llx"
#define	PRIuPSIZE	"llu"
#else /* PAE */
typedef unsigned long	paddr_t;
typedef unsigned long	psize_t;
#define	PRIxPADDR	"lx"
#define	PRIxPSIZE	"lx"
#define	PRIuPSIZE	"lu"
#endif /* PAE */

#elif defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)
/* paddr_t is always 64 bits for userland */
typedef __uint64_t	paddr_t;
typedef __uint64_t	psize_t;
#define	PRIxPADDR	"llx"
#define	PRIxPSIZE	"llx"
#define	PRIuPSIZE	"llu"

#endif /* _KERNEL */

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)

typedef __vaddr_t	vaddr_t;
typedef unsigned long	vsize_t;
#define	PRIxVADDR	"lx"
#define	PRIxVSIZE	"lx"
#define	PRIuVSIZE	"lu"

typedef __register_t	register_t;
#define	PRIxREGISTER	"x"

#endif /* _KERNEL || _KMEMUSER */

/* __cpu_simple_lock_t used to be a full word. */
#define	__CPU_SIMPLE_LOCK_PAD

#define	__SIMPLELOCK_LOCKED	1
#define	__SIMPLELOCK_UNLOCKED	0

#if !__has_feature(undefined_behavior_sanitizer) && \
	!defined(__SANITIZE_UNDEFINED__)
/* The x86 does not have strict alignment requirements. */
#define	__NO_STRICT_ALIGNMENT
#endif

#define	__HAVE_NEW_STYLE_BUS_H
#define	__HAVE_CPU_DATA_FIRST
#define	__HAVE_CPU_COUNTER
#define	__HAVE_CPU_BOOTCONF
#define	__HAVE_MD_CPU_OFFLINE
#define	__HAVE_SYSCALL_INTERN
#define	__HAVE_MINIMAL_EMUL
#define	__HAVE_OLD_DISKLABEL
#define	__HAVE_CPU_RNG

#if defined(_KERNEL)
/*
 * Processors < i586 do not have cmpxchg8b, and we compile for i486
 * by default. The kernel tsc driver uses them though, and handles < i586
 * by patching.  E.g. rump kernels and crash(8) and a selection of
 * other run-in-userspace code defines _KERNEL, but is careful not to
 * build anything using 64bit atomic ops by default.
 */
#define	__HAVE_ATOMIC64_OPS
#endif
#define	__HAVE_ATOMIC_AS_MEMBAR
#define	__HAVE_CPU_LWP_SETPRIVATE
#define	__HAVE_INTR_CONTROL
#define	__HAVE_MM_MD_OPEN
#define	__HAVE___LWP_GETPRIVATE_FAST
#define	__HAVE_TLS_VARIANT_II
#define	__HAVE_COMMON___TLS_GET_ADDR
#define	__HAVE_UCAS_FULL
#define	__HAVE_RAS

#endif	/* _I386_MACHTYPES_H_ */