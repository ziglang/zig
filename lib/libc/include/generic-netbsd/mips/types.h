/*	$NetBSD: types.h,v 1.77.4.1 2023/04/03 18:30:41 martin Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
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
 *	@(#)types.h	8.3 (Berkeley) 1/5/94
 */

#ifndef	_MIPS_TYPES_H_
#define	_MIPS_TYPES_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <mips/int_types.h>

typedef __int32_t		__register32_t;
typedef __int64_t		__register64_t;
typedef __uint32_t		__fpregister32_t;
typedef __uint64_t		__fpregister64_t;

typedef	unsigned int		__cpu_simple_lock_nv_t;
#if defined(__mips_o32)
typedef __register32_t		__register_t;
typedef __fpregister32_t	__fpregister_t;
#else
typedef __register64_t		__register_t;
typedef __fpregister64_t	__fpregister_t;
#endif

/*
 * Note that mips_reg_t is distinct from the register_t defined
 * in <types.h> to allow these structures to be as hidden from
 * the rest of the operating system as possible.
 */

#ifdef _LP64
typedef __uint64_t	__vaddr_t;
#else
typedef __uint32_t	__vaddr_t;
#endif

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_KERNTYPES) || defined(_STANDALONE)
#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
typedef __uint64_t	paddr_t;
typedef __uint64_t	psize_t;
#define	PRIxPADDR	PRIx64
#define	PRIxPSIZE	PRIx64
#define	PRIdPSIZE	PRId64
#define	PRIuPSIZE	PRIu64
#else
typedef __uint32_t	paddr_t;
typedef __uint32_t	psize_t;
#define	PRIxPADDR	PRIx32
#define	PRIxPSIZE	PRIx32
#define	PRIdPSIZE	PRId32
#define	PRIuPSIZE	PRIu32
#endif
#ifdef _LP64
typedef __uint64_t	vaddr_t;
typedef __uint64_t	vsize_t;
#define	PRIxVADDR	PRIx64
#define	PRIxVSIZE	PRIx64
#define	PRIdVSIZE	PRId64
#define	PRIuVSIZE	PRIu64
#else
typedef __uint32_t	vaddr_t;
typedef __uint32_t	vsize_t;
#define	PRIxVADDR	PRIx32
#define	PRIxVSIZE	PRIx32
#define	PRIdVSIZE	PRId32
#define	PRIuVSIZE	PRIu32
#endif

typedef	vaddr_t	vm_offset_t;	/* deprecated (cddl/FreeBSD compat) */
typedef	vsize_t	vm_size_t;	/* deprecated (cddl/FreeBSD compat) */


typedef int		mips_prid_t;
/* Make sure this is signed; we need pointers to be sign-extended. */
typedef	__fpregister_t	fpregister_t;
typedef	__fpregister_t	mips_fpreg_t;		/* do not use */
typedef __register_t	register_t;
typedef __register_t	mips_reg_t;

#if defined(__mips_o32)
typedef __uint32_t	uregister_t;
typedef __uint32_t	mips_ureg_t;		/* do not use */
#define	PRIxREGISTER	PRIx32
#define	PRIxUREGISTER	PRIx32
#else
typedef __uint64_t	uregister_t;
typedef __uint64_t	mips_ureg_t;		/* do not use */
typedef __int64_t	register32_t;
typedef __uint64_t	uregister32_t;
#define	PRIxREGISTER	PRIx64
#define	PRIxUREGISTER	PRIx64
#endif /* __mips_o32 */

#if defined(_KMEMUSER)
typedef struct mips_label_t {
	register_t val[14];
} mips_label_t;
#else
typedef struct label_t {
	register_t val[14];
} label_t;
typedef label_t mips_label_t;
#endif

#define	_L_S0		0
#define	_L_S1		1
#define	_L_S2		2
#define	_L_S3		3
#define	_L_S4		4
#define	_L_S5		5
#define	_L_S6		6
#define	_L_S7		7
#define	_L_T8		8
#define	_L_GP		9
#define	_L_SP		10
#define	_L_S8		11
#define	_L_RA		12
#define	_L_SR		13

typedef __uint32_t tlb_asid_t;
#endif /* _KERNEL */

#if defined(_KERNEL) || defined(_KMEMUSER)
#define	PCU_FPU		0
#define	PCU_DSP		1
#define	PCU_UNIT_COUNT	2
#endif

#define	__SIMPLELOCK_LOCKED	1
#define	__SIMPLELOCK_UNLOCKED	0

#define	__HAVE_COMMON___TLS_GET_ADDR
#define	__HAVE_CPU_COUNTER
#define	__HAVE_CPU_DATA_FIRST
#define	__HAVE_CPU_LWP_SETPRIVATE
#define	__HAVE_CPU_UAREA_ROUTINES
#define	__HAVE_FAST_SOFTINTS
#define	__HAVE_MD_CPU_OFFLINE
#define	__HAVE_MM_MD_DIRECT_MAPPED_PHYS
#define	__HAVE_MM_MD_KERNACC
#define	__HAVE_MM_MD_CACHE_ALIASING
#define	__HAVE_SYSCALL_INTERN
#define	__HAVE_TLS_VARIANT_I
#define	__HAVE_UCAS_FULL
#define	__HAVE___LWP_GETTCB_FAST
#define	__HAVE___LWP_SETTCB
#define	__HAVE_BUS_SPACE_8

/* XXX temporary */
#define	__HAVE_UNLOCKED_PMAP

#if !defined(__mips_o32)
#define	__HAVE_ATOMIC64_OPS
#endif

#if defined(_KERNEL)
#define	__HAVE_RAS
#if defined(_LP64)
#define	__HAVE_CPU_VMSPACE_EXEC
#endif
#endif /* _KERNEL */


#endif	/* _MIPS_TYPES_H_ */