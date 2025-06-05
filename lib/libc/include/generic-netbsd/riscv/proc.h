/*	$NetBSD: proc.h,v 1.3 2015/03/31 06:47:47 matt Exp $	*/

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

#ifndef _RISCV_PROC_H_
#define _RISCV_PROC_H_

#include <sys/param.h>
#include <riscv/vmparam.h>

struct lwp;

/*
 * Machine-dependent part of the lwp structure for RISCV
 */
struct trapframe;

struct mdlwp {
	struct trapframe *md_utf;	/* trapframe from userspace */
	struct trapframe *md_ktf;	/* trapframe from userspace */
	struct faultbuf *md_onfault;	/* registers to store on fault */
	register_t md_usp;		/* for locore.S */
	vaddr_t	md_ss_addr;		/* single step address for ptrace */
	int	md_ss_instr;		/* single step instruction for ptrace */
	volatile int md_astpending;	/* AST pending on return to userland */
#if 0
#if USPACE > PAGE_SIZE
	int	md_upte[USPACE/4096];	/* ptes for mapping u page */
#else
	int	md_dpte[USPACE/4096];	/* dummy ptes to keep the same */
#endif
#endif
};

struct mdproc {
					/* syscall entry for this process */
	void	(*md_syscall)(struct trapframe *);
};

#ifdef _KERNEL
#define	LWP0_CPU_INFO	&cpu_info_store	/* staticly set in lwp0 */
#endif /* _KERNEL */

#endif /* _RISCV_PROC_H_ */