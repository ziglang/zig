/* $NetBSD: types.h,v 1.15 2022/11/08 13:34:17 simonb Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef	_RISCV_TYPES_H_
#define	_RISCV_TYPES_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <riscv/int_types.h>

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)

/* XLEN is the native base integer ISA width */
#define	XLEN		(sizeof(long) * NBBY)

typedef __uint64_t	paddr_t;
typedef __uint64_t	psize_t;
#define	PRIxPADDR	PRIx64
#define	PRIxPSIZE	PRIx64
#define	PRIuPSIZE	PRIu64

typedef __UINTPTR_TYPE__	vaddr_t;
typedef __UINTPTR_TYPE__	vsize_t;
#define	PRIxVADDR	PRIxPTR
#define	PRIxVSIZE	PRIxPTR
#define	PRIuVSIZE	PRIuPTR

#ifdef _LP64			// match <riscv/reg.h>
#define	PRIxREGISTER	PRIx64
typedef __int64_t register_t;
typedef __uint64_t uregister_t;
#else
#define	PRIxREGISTER	PRIx32
typedef __int32_t register_t;
typedef __uint32_t uregister_t;
#endif
typedef signed int register32_t;
typedef unsigned int uregister32_t;
#define	PRIxREGISTER32	"x"

typedef unsigned int tlb_asid_t;
#endif

#if defined(_KERNEL)
typedef struct label_t {	/* Used by setjmp & longjmp */
        register_t lb_reg[16];	/* */
	__uint32_t lb_sr;
} label_t;
#endif

typedef	unsigned int	__cpu_simple_lock_nv_t;
#ifdef _LP64
typedef __int64_t	__register_t;
#else
typedef __int32_t	__register_t;
#endif

#define	__SIMPLELOCK_LOCKED	1
#define	__SIMPLELOCK_UNLOCKED	0

#define	__HAVE_COMMON___TLS_GET_ADDR
#define	__HAVE_COMPAT_NETBSD32
#define	__HAVE_CPU_COUNTER
#define	__HAVE_CPU_DATA_FIRST
#define	__HAVE_FAST_SOFTINTS
#define	__HAVE_MM_MD_DIRECT_MAPPED_PHYS
#define	__HAVE_NEW_STYLE_BUS_H
#define	__HAVE_SYSCALL_INTERN
#define	__HAVE_TLS_VARIANT_I
/* XXX temporary */
#define	__HAVE_UNLOCKED_PMAP
#define	__HAVE___LWP_GETPRIVATE_FAST

#ifdef __LP64
#define	__HAVE_ATOMIC64_OPS
#define	__HAVE_CPU_UAREA_ROUTINES
#endif

//#if defined(_KERNEL)
//#define	__HAVE_RAS
//#endif

#if defined(_KERNEL) || defined(_KMEMUSER)
#define	PCU_FPU		0
#define	PCU_UNIT_COUNT	1
#endif

#endif	/* _RISCV_TYPES_H_ */