/*	$NetBSD: proc.h,v 1.48 2020/06/13 23:58:52 ad Exp $	*/

/*
 * Copyright (c) 1991 Regents of the University of California.
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
 *	@(#)proc.h	7.1 (Berkeley) 5/15/91
 */

#ifndef _I386_PROC_H_
#define _I386_PROC_H_

#include <machine/frame.h>
#include <machine/pcb.h>

/*
 * Machine-dependent part of the lwp structure for i386.
 */
struct pmap;
struct vm_page;

#define	MDL_FPU_IN_CPU		0x0020	/* the FPU state is in the CPU */

struct mdlwp {
	volatile uint64_t md_tsc;	/* last TSC reading */
	struct	trapframe *md_regs;	/* registers on current frame */
	int	md_flags;		/* machine-dependent flags */
	volatile int md_astpending;	/* AST pending for this process */
};

/* md_flags */
#define	MDL_IOPL		0x0002	/* XEN: i/o privilege */

struct mdproc {
	int	md_flags;
	void	(*md_syscall)(struct trapframe *);
					/* Syscall handling function */
};

/* md_flags */
#define MDP_USEDMTRR	0x0002	/* has set volatile MTRRs */

#endif /* _I386_PROC_H_ */