/*	$NetBSD: mips_param.h,v 1.52 2021/10/04 21:02:40 andvar Exp $	*/

/*-
 * Copyright (c) 2013 The NetBSD Foundation, Inc.
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

#ifdef _KERNEL_OPT
#include "opt_param.h"
#endif

/*
 * No reason this can't be common
 */
#if defined(__MIPSEB__)
# define _MACHINE_SUFFIX eb
# define MACHINE_SUFFIX "eb"
#elif defined(__MIPSEL__)
# define _MACHINE_SUFFIX el
# define MACHINE_SUFFIX "el"
#else
# error neither __MIPSEL__ nor __MIPSEB__ are defined.
#endif

#define	___MACHINE32_OARCH		mips##_MACHINE_SUFFIX
#define	__MACHINE32_OARCH		"mips" MACHINE_SUFFIX
#define	___MACHINE32_NARCH		mips64##_MACHINE_SUFFIX
#define	__MACHINE32_NARCH		"mips64" MACHINE_SUFFIX
#define	___MACHINE64_NARCH		mipsn64##_MACHINE_SUFFIX
#define	__MACHINE64_NARCH		"mipsn64" MACHINE_SUFFIX

#if defined(__mips_n32) || defined(__mips_n64)
# if defined(__mips_n32)
#  define	_MACHINE_ARCH		___MACHINE32_NARCH
#  define	MACHINE_ARCH		__MACHINE32_NARCH
# else /* __mips_n64 */
#  define	_MACHINE_ARCH		___MACHINE64_NARCH
#  define	MACHINE_ARCH		__MACHINE64_NARCH
#  define	_MACHINE32_NARCH	___MACHINE32_NARCH
#  define	MACHINE32_NARCH		__MACHINE32_NARCH
# endif
# define	_MACHINE32_OARCH	___MACHINE32_OARCH
# define	MACHINE32_OARCH		__MACHINE32_OARCH
#else /* o32 */
# define	_MACHINE_ARCH		___MACHINE32_OARCH
# define	MACHINE_ARCH		__MACHINE32_OARCH
#endif

/*
 * Userland code should be using uname/sysctl to get MACHINE so simply
 * export a generic MACHINE of "mips"
 */
#ifndef _KERNEL
#undef MACHINE
#define	MACHINE "mips"
#endif

#define	ALIGNBYTES32		(sizeof(double) - 1)
#define	ALIGN32(p)		(((uintptr_t)(p) + ALIGNBYTES32) &~ALIGNBYTES32)

/*
 * On mips, UPAGES is fixed by sys/arch/mips/mips/locore code
 * to be the number of per-process-wired kernel-stack pages/PTES.
 */

#define	SSIZE		1		/* initial stack size/NBPG */
#define	SINCR		1		/* increment of stack/NBPG */

#if (ENABLE_MIPS_16KB_PAGE + ENABLE_MIPS_8KB_PAGE + ENABLE_MIPS_4KB_PAGE) > 1
#error only one of ENABLE_MIPS_{4,8,16}KB_PAGE can be defined.
#endif

#ifndef MSGBUFSIZE
#define	MSGBUFSIZE	NBPG		/* default message buffer size */
#endif

/*
 * Most MIPS have a cache line size of 32 bytes, but Cavium chips
 * have a line size 128 bytes and we need to cover the larger size.
 */
#define	COHERENCY_UNIT	128
#define	CACHE_LINE_SIZE	128

#ifdef ENABLE_MIPS_16KB_PAGE
#define	PGSHIFT		14		/* LOG2(NBPG) */
#elif defined(ENABLE_MIPS_8KB_PAGE) \
    || (!defined(ENABLE_MIPS_4KB_PAGE) && __mips >= 3)
#define	PGSHIFT		13		/* LOG2(NBPG) */
#else
#define	PGSHIFT		12		/* LOG2(NBPG) */
#endif
#define	NBPG		(1 << PGSHIFT)	/* bytes/page */
#define	PGOFSET		(NBPG - 1)	/* byte offset into page */
#define	PTPSHIFT	2
#define	PTPLENGTH	(PGSHIFT - PTPSHIFT)
#define	NPTEPG		(1 << PTPLENGTH)

#define	SEGSHIFT	(PGSHIFT + PTPLENGTH)	/* LOG2(NBSEG) */
#define	NBSEG		(1 << SEGSHIFT)	/* bytes/segment */
#define	SEGOFSET	(NBSEG - 1)	/* byte offset into segment */

#ifdef _LP64
#define	SEGLENGTH	(PGSHIFT - 3)
#define	XSEGSHIFT	(SEGSHIFT + SEGLENGTH)	/* LOG2(NBXSEG) */
#define	NBXSEG		(1UL << XSEGSHIFT)	/* bytes/xsegment */
#define	XSEGOFSET	(NBXSEG - 1)	/* byte offset into xsegment */
#define	XSEGLENGTH	(PGSHIFT - 3)
#define	NXSEGPG		(1 << XSEGLENGTH)
#else
#define	SEGLENGTH	(31 - SEGSHIFT)
#endif
#define	NSEGPG		(1 << SEGLENGTH)

#ifdef _LP64
#define	__MIN_USPACE	16384		/* LP64 needs a 16kB stack */
#else
/*
 * Note for the non-LP64 case, cpu_switch_resume has the assumption
 * that UPAGES == 2.  For MIPS-I we wire USPACE in TLB #0 and #1.
 * For MIPS3+ we wire USPACE in the TLB #0 pair.
 */
#define	__MIN_USPACE	8192		/* otherwise use an 8kB stack */
#endif
#define	USPACE		MAX(__MIN_USPACE, PAGE_SIZE)
#define	UPAGES		(USPACE / PAGE_SIZE) /* number of pages for u-area */
#define	USPACE_ALIGN	USPACE		/* make sure it starts on a even VA */
#define	UPAGES_MAX	8		/* a (constant) max for userland use */

/*
 * Minimum and maximum sizes of the kernel malloc arena in PAGE_SIZE-sized
 * logical pages.
 */
#define	NKMEMPAGES_MIN_DEFAULT	((8 * 1024 * 1024) >> PAGE_SHIFT)
#define	NKMEMPAGES_MAX_DEFAULT	((128 * 1024 * 1024) >> PAGE_SHIFT)

/*
 * Mach derived conversion macros
 */
#define	mips_round_page(x)	((((uintptr_t)(x)) + NBPG - 1) & ~(NBPG-1))
#define	mips_trunc_page(x)	((uintptr_t)(x) & ~(NBPG-1))
#define	mips_btop(x)		((paddr_t)(x) >> PGSHIFT)
#define	mips_ptob(x)		((paddr_t)(x) << PGSHIFT)

#ifdef __MIPSEL__
#define	MID_MACHINE	MID_PMAX	/* MID_PMAX (little-endian) */
#endif
#ifdef __MIPSEB__
#define	MID_MACHINE	MID_MIPS	/* MID_MIPS (big-endian) */
#endif

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than NBPG (the software page size), and,
 * on machines that exchange pages of input or output buffers with mbuf
 * clusters (MAPPED_MBUFS), MCLBYTES must also be an integral multiple
 * of the hardware page size.
 */
#ifndef MSIZE
#ifdef _LP64
#define	MSIZE		512		/* size of an mbuf */
#else
#define	MSIZE		256		/* size of an mbuf */
#endif

#ifndef MCLSHIFT
# define MCLSHIFT	11		/* convert bytes to m_buf clusters */
#endif	/* MCLSHIFT */

#define	MCLBYTES	(1 << MCLSHIFT)	/* size of a m_buf cluster */

#endif