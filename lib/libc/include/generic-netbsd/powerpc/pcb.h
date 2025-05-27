/*	$NetBSD: pcb.h,v 1.23 2021/10/27 18:20:23 christos Exp $	*/

/*-
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
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
#ifndef	_POWERPC_PCB_H_
#define	_POWERPC_PCB_H_

#include <powerpc/reg.h>
#include <powerpc/frame.h>

struct faultbuf {
	register_t fb_sp;		/* R1 */
	register_t fb_r2;		/* R2 (why?) */
	/*
	 * These are ordered so that one could use a stmw to save them.
	 */
	register_t fb_msr;		/* MSR */
	register_t fb_pc;		/* PC */
	register_t fb_cr;		/* CR */
	register_t fb_fixreg[19];	/* R13-R31 */
};

struct pcb {
	struct pmap *pcb_pm;	/* pmap of our vmspace */
	register_t pcb_sp;	/* saved SP */
	int pcb_flags;
#define	PCB_FE1		PSL_FE1	/* 0x100 */
#define	PCB_FE0		PSL_FE0	/* 0x800 */
	struct faultbuf *pcb_onfault;	/* For use during copyin/copyout */
	vaddr_t pcb_kmapsr;	/* where to map user segment in kernel */
	vaddr_t pcb_umapsr;	/* the user segment mapped in kernel */
	struct fpreg pcb_fpu;	/* Floating point processor */
	struct vreg pcb_vr __attribute__((aligned(16)));
	register_t pcb_usprg0;	/* User Special-Purpose Register General 0 */
};

struct md_coredump {
	struct trapframe frame;
	struct fpreg fpstate;
	struct vreg vstate;
};

#ifdef _KERNEL
int setfault(struct faultbuf *);
#endif

#endif	/* _POWERPC_PCB_H_ */