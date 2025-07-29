/* $NetBSD: param.h,v 1.16 2021/05/31 14:38:57 simonb Exp $ */

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

#ifndef _AARCH64_PARAM_H_
#define _AARCH64_PARAM_H_

#ifdef __aarch64__

#ifdef _KERNEL_OPT
#include "opt_cputypes.h"
#include "opt_param.h"
#endif

/*
 * Machine dependent constants for all ARM processors
 */

/*
 * For KERNEL code:
 *	MACHINE must be defined by the individual port.  This is so that
 *	uname returns the correct thing, etc.
 *
 *	MACHINE_ARCH may be defined by individual ports as a temporary
 *	measure while we're finishing the conversion to ELF.
 *
 * For non-KERNEL code:
 *	If ELF, MACHINE and MACHINE_ARCH are forced to "arm/armeb".
 */

#if defined(_KERNEL)
# ifndef MACHINE_ARCH		/* XXX For now */
#  ifdef __AARCH64EB__
#   define	_MACHINE_ARCH	aarch64eb
#   define	MACHINE_ARCH	"aarch64eb"
#   define	_MACHINE32_ARCH	earmv7hfeb
#   define	MACHINE32_ARCH	"earmv7hfeb"
#  else
#   define	_MACHINE_ARCH	aarch64
#   define	MACHINE_ARCH	"aarch64"
#   define	_MACHINE32_ARCH	earmv7hf
#   define	MACHINE32_ARCH	"earmv7hf"
#  endif /* __AARCH64EB__ */
# endif /* MACHINE_ARCH */
#else
# undef _MACHINE
# undef MACHINE
# undef _MACHINE_ARCH
# undef MACHINE_ARCH
# undef _MACHINE32_ARCH
# undef MACHINE32_ARCH
# define	_MACHINE	aarch64
# define	MACHINE		"aarch64"
# ifdef __AARCH64EB__
#  define	_MACHINE_ARCH	aarch64eb
#  define	MACHINE_ARCH	"aarch64eb"
#  define	_MACHINE32_ARCH	earmv7hfeb
#  define	MACHINE32_ARCH	"earmv7hfeb"
# else
#  define	_MACHINE_ARCH	aarch64
#  define	MACHINE_ARCH	"aarch64"
#  define	_MACHINE32_ARCH	earmv7hf
#  define	MACHINE32_ARCH	"earmv7hf"
# endif /* __AARCH64EB__ */
#endif /* !_KERNEL */

#define	MID_MACHINE	MID_AARCH64

/* AARCH64-specific macro to align a stack pointer (downwards). */
#define STACK_ALIGNBYTES	(16 - 1)

#define ALIGNBYTES32		(8 - 1)
#define ALIGN32(p)		\
	(((uintptr_t)(p) + ALIGNBYTES32) & ~ALIGNBYTES32)

#define NKMEMPAGES_MIN_DEFAULT		((128UL * 1024 * 1024) >> PAGE_SHIFT)
#define NKMEMPAGES_MAX_UNLIMITED	1

#ifdef AARCH64_PAGE_SHIFT
#if (1 << AARCH64_PAGE_SHIFT) & ~0x141000
#error AARCH64_PAGE_SHIFT contains an unsupported value.
#endif
#define PGSHIFT			AARCH64_PAGE_SHIFT
#else
#define PGSHIFT			12
#endif
#define NBPG			(1 << PGSHIFT)
#define PGOFSET			(NBPG - 1)

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than NBPG (the software page size), and
 * NBPG % MCLBYTES must be zero.
 */
#if PGSHIFT > 12
#define MSIZE			256	/* size of an mbuf */
#else
#define MSIZE			512	/* size of an mbuf */
#endif

#ifndef MCLSHIFT
#define MCLSHIFT		11	/* convert bytes to m_buf clusters */
					/* 2K cluster can hold Ether frame */
#endif /* MCLSHIFT */

#define MCLBYTES		(1 << MCLSHIFT)	/* size of a m_buf cluster */

#ifndef NFS_RSIZE
#define NFS_RSIZE		32768	/* Default NFS read data size */
#endif
#ifndef NFS_WSIZE
#define NFS_WSIZE		32768	/* Default NFS write data size */
#endif

#ifndef MSGBUFSIZE
#define MSGBUFSIZE		65536	/* default message buffer size */
#endif

#define COHERENCY_UNIT		128
#define CACHE_LINE_SIZE		128

#define MAXCPUS			256

#ifdef _KERNEL

#ifndef __HIDE_DELAY
void delay(unsigned int);
#define	DELAY(x)	delay(x)
#endif
/*
 * Compatibility /dev/zero mapping.
 */
#ifdef COMPAT_16
#define COMPAT_ZERODEV(x)	(x == makedev(0, _DEV_ZERO_oARM))
#endif

#endif /* _KERNEL */

#define aarch64_btop(x)		((unsigned long)(x) >> PGSHIFT)
#define aarch64_ptob(x)		((unsigned long)(x) << PGSHIFT)
#define aarch64_trunc_page(x)	((unsigned long)(x) & ~PGSHIFT)
#define aarch64_round_page(x)	((((unsigned long)(x)) + PGOFSET) & ~PGOFSET)

/* compatibility for arm */
#define arm_btop(x)		aarch64_btop(x)
#define arm_ptob(x)		aarch64_ptob(x)

#elif defined(__arm__)

#include <arm/param.h>

#endif /* __aarch64__/__arm__ */

#endif /* _AARCH64_PARAM_H_ */