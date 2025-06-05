/*	$NetBSD: pcb.h,v 1.28 2021/03/13 17:14:11 skrll Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department and Ralph Campbell.
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
 * from: Utah Hdr: pcb.h 1.13 89/04/23
 *
 *	@(#)pcb.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _MIPS_PCB_H_
#define	_MIPS_PCB_H_

#include <mips/types.h>
#include <mips/reg.h>

struct pcb_faultinfo {
	void *pfi_faultptep;
	vaddr_t pfi_faultaddr;
	u_int pfi_repeats;
	pid_t pfi_lastpid;
	uint8_t pfi_faulttype;
};

/*
 * MIPS process control block
 */
struct pcb {
	mips_label_t pcb_context;	/* kernel context for resume */
	void *pcb_onfault;		/* for copyin/copyout faults */
	uint32_t pcb_ppl;		/* previous priority level */
	struct fpreg pcb_fpregs;	/* saved floating point registers */
	struct dspreg pcb_dspregs;	/* saved DSP registers */
	struct pcb_faultinfo pcb_faultinfo;
};

/*
 * The pcb is augmented with machine-dependent additional data for
 * core dumps.
 */
struct md_coredump {
	mips_reg_t md_regs[38];
	struct fpreg md_fpregs;
};

#ifdef _KERNEL
#define	PCB_FSR(pcb)	((pcb)->pcb_fpregs.r_regs[_R_FSR - _FPBASE])
#endif

#ifndef _KERNEL
/* Connect the dots for crash(8). */
vaddr_t db_mach_addr_cpuswitch(void);
#endif

#endif /*_MIPS_PCB_H_*/