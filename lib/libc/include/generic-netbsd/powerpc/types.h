/*	$NetBSD: types.h,v 1.66 2021/04/01 04:35:46 simonb Exp $	*/

/*-
 * Copyright (C) 1995 Wolfgang Solfrank.
 * Copyright (C) 1995 TooLs GmbH.
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_POWERPC_TYPES_H_
#define	_POWERPC_TYPES_H_

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <powerpc/int_types.h>

typedef int __cpu_simple_lock_nv_t;
typedef unsigned long __register_t;	/* frame.h */
typedef __uint32_t __register32_t;	/* frame.h */

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)
typedef	unsigned long	paddr_t, vaddr_t;
typedef	unsigned long	psize_t, vsize_t;
#define	PRIxPADDR	"lx"
#define	PRIxPSIZE	"lx"
#define	PRIuPSIZE	"lu"
#define	PRIxVADDR	"lx"
#define	PRIxVSIZE	"lx"
#define	PRIuVSIZE	"lu"

/*
 * Because lwz etal don't sign extend, it's best to make registers unsigned.
 */
typedef __register_t register_t;
typedef __register32_t register32_t;
typedef __uint64_t register64_t;
#define	PRIxREGISTER	"lx"
#define	PRIxREGISTER64	PRIx64
#define	PRIxREGISTER32	PRIx32
#endif

#if defined(_KERNEL)
typedef struct label_t {
	register_t val[40]; /* double check this XXX */
} label_t;

typedef __uint32_t tlb_asid_t;		/* for booke */
#endif

#define	__SIMPLELOCK_LOCKED	1
#define	__SIMPLELOCK_UNLOCKED	0

#define	__HAVE_CPU_COUNTER
#define	__HAVE_NEW_STYLE_BUS_H
#define	__HAVE_SYSCALL_INTERN
#define	__HAVE_CPU_DATA_FIRST
#define	__HAVE_CPU_UAREA_ROUTINES
#ifdef _LP64
#define	__HAVE_ATOMIC64_OPS
#endif
#define	__HAVE_CPU_LWP_SETPRIVATE
#define	__HAVE_COMMON___TLS_GET_ADDR
#define	__HAVE___LWP_GETTCB_FAST
#define	__HAVE___LWP_SETTCB
#define	__HAVE_TLS_VARIANT_I
#define	__HAVE_BUS_SPACE_8

#if defined(_KERNEL) || defined(_KMEMUSER)
#define	PCU_FPU		0	/* FPU */
#define	PCU_VEC		1	/* AltiVec/SPE */
#define	PCU_UNIT_COUNT	2
#endif

#define	__HAVE_MM_MD_DIRECT_MAPPED_PHYS
#define	__HAVE_MM_MD_KERNACC
#if 0	/* XXX CPU configuration spaghetti */
#define	__HAVE_UCAS_FULL
#endif
#if defined(_KERNEL)
#define	__HAVE_RAS
#endif

#ifndef PPC_IBM4XX
/* XXX temporary */
#define	__HAVE_UNLOCKED_PMAP
#endif

#endif	/* _POWERPC_TYPES_H_ */