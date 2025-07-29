/* $NetBSD: param.h,v 1.7 2022/10/12 07:50:00 simonb Exp $ */

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

#ifndef	_RISCV_PARAM_H_
#define	_RISCV_PARAM_H_

#ifdef _KERNEL_OPT
#include "opt_param.h"
#endif

/*
 * Machine dependent constants for all OpenRISC processors
 */

/*
 * For KERNEL code:
 *	MACHINE must be defined by the individual port.  This is so that
 *	uname returns the correct thing, etc.
 *
 * For non-KERNEL code:
 *	If ELF, MACHINE and MACHINE_ARCH are forced to "or1k/or1k".
 */

#ifdef _LP64
#define	_MACHINE_ARCH	riscv64
#define	MACHINE_ARCH	"riscv64"
#define	_MACHINE_ARCH32	riscv32
#define	MACHINE_ARCH32	"riscv32"
#else
#define	_MACHINE_ARCH	riscv32
#define	MACHINE_ARCH	"riscv32"
#endif
#define	_MACHINE	riscv
#define	MACHINE		"riscv"

#define	MID_MACHINE	MID_RISCV

/* RISCV-specific macro to align a stack pointer (downwards). */
#define STACK_ALIGNBYTES	(__BIGGEST_ALIGNMENT__ - 1)
#define	ALIGNBYTES32	__BIGGEST_ALIGNMENT__

#define NKMEMPAGES_MIN_DEFAULT		((128UL * 1024 * 1024) >> PAGE_SHIFT)
#define NKMEMPAGES_MAX_UNLIMITED	1

#define PGSHIFT		12
#define	NBPG		(1 << PGSHIFT)
#define PGOFSET		(NBPG - 1)

#define UPAGES		2
#define	USPACE		(UPAGES << PGSHIFT)
#define USPACE_ALIGN	NBPG

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than NBPG (the software page size), and
 * NBPG % MCLBYTES must be zero.
 */
#define	MSIZE		512		/* size of an mbuf */

#ifndef MCLSHIFT
#define	MCLSHIFT	11		/* convert bytes to m_buf clusters */
					/* 2K cluster can hold Ether frame */
#endif	/* MCLSHIFT */

#define	MCLBYTES	(1 << MCLSHIFT)	/* size of a m_buf cluster */

#ifndef MSGBUFSIZE
#define MSGBUFSIZE		65536	/* default message buffer size */
#endif

#define MAXCPUS			32

#ifdef _KERNEL
void delay(unsigned long);
#define	DELAY(x)	delay(x)
#endif

#endif /* _RISCV_PARAM_H_ */