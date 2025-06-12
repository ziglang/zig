/*	$NetBSD: types.h,v 1.72 2022/07/30 14:13:27 riastradh Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)types.h	8.1 (Berkeley) 6/11/93
 */

#ifndef	_MACHTYPES_H_
#define	_MACHTYPES_H_

#ifdef sun
#undef sun
#endif

#if defined(_KERNEL_OPT)
#include "opt_multiprocessor.h"
#include "opt_sparc_arch.h"
#endif

#ifndef _LOCORE

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/int_types.h>

/* The following are unsigned to prevent annoying sign extended pointers. */
#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)
typedef unsigned long int	register_t;
#define	PRIxREGISTER		"lx"
typedef unsigned int		register32_t;
#define	PRIxREGISTER32		"x"
#ifdef __arch64__
typedef unsigned long int	register64_t;
#define	PRIxREGISTER64		"lx"
#else
/* LONGLONG */
typedef unsigned long long int	register64_t;
#define	PRIxREGISTER64		"llx"
#endif
#endif

#if defined(_KERNEL)
typedef struct label_t {
#ifdef __sparc_v9__
	register64_t val[2];
#else
	register_t val[3];
#endif
} label_t;
#endif

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)
typedef unsigned long int	vaddr_t;
typedef vaddr_t			vsize_t;
#define	PRIxVADDR		"lx"
#define	PRIxVSIZE		"lx"
#define	PRIuVSIZE		"lu"
#ifdef __sparc_v9__
#ifdef __arch64__
typedef unsigned long int	paddr_t;
#define	PRIxPADDR		"lx"
#define	PRIuPSIZE		"lu"
#else
/* LONGLONG */
typedef unsigned long long int	paddr_t;
#define	PRIxPADDR		"llx"
#define	PRIuPSIZE		"llu"
#endif /* __arch64__ */
#else
typedef unsigned long int	paddr_t;
#define	PRIxPADDR		"lx"
#define	PRIuPSIZE		"lu"
#endif /* __sparc_v9__ */
typedef paddr_t			psize_t;
#define	PRIxPSIZE		PRIxPADDR
#endif

typedef	unsigned char		__cpu_simple_lock_nv_t;
typedef unsigned long int	__register_t;

/* __cpu_simple_lock_t used to be a full word. */
#define	__CPU_SIMPLE_LOCK_PAD

#define	__SIMPLELOCK_LOCKED	0xff
#define	__SIMPLELOCK_UNLOCKED	0

#endif /* _LOCORE */

#define	__HAVE_NEW_STYLE_BUS_H
#define	__HAVE_SYSCALL_INTERN
#define	__GENERIC_SOFT_INTERRUPTS_ALL_LEVELS
#define	__HAVE_CPU_VMSPACE_EXEC
#define	__HAVE_RAS
#define	__HAVE_BUS_SPACE_8

#ifdef __sparc_v9__
#define	__HAVE_CPU_DATA_FIRST
#define	__HAVE_DEVICE_REGISTER_POSTCONFIG
#define	__HAVE_ATOMIC64_OPS
#define	__HAVE_CPU_COUNTER	/* sparc v9 CPUs have %tick */
#define	__HAVE_FAST_SOFTINTS
#else
#define	__HAVE_MM_MD_READWRITE
#ifdef MULTIPROCESSOR
#define	__HAVE_HASHLOCKED_ATOMICS
#endif
#endif

#define	__HAVE_CPU_LWP_SETPRIVATE
#define	__HAVE___LWP_GETPRIVATE_FAST
#define	__HAVE_TLS_VARIANT_II
#define	__HAVE_COMMON___TLS_GET_ADDR

#endif	/* _MACHTYPES_H_ */