/*	$NetBSD: pcb.h,v 1.59 2019/10/12 06:31:03 maxv Exp $	*/

/*
 * Copyright (c) 1998, 2009 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum, and by Andrew Doran.
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

/*
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	@(#)pcb.h	5.10 (Berkeley) 5/12/91
 */

/*
 * Intel 386 process control block
 */

#ifndef _I386_PCB_H_
#define _I386_PCB_H_

#if defined(_KERNEL_OPT)
#include "opt_multiprocessor.h"
#endif

#include <machine/segments.h>
#include <x86/cpu_extended_state.h>

struct pcb {
	int	pcb_esp0;		/* ring0 esp */
	int	pcb_esp;		/* kernel esp */
	int	pcb_ebp;		/* kernel ebp */
	int	pcb_cr0;		/* saved image of CR0 */
	int	pcb_cr2;		/* page fault address (CR2) */
	int	pcb_cr3;		/* page directory pointer */
	int	pcb_iopl;		/* i/o privilege level */

	struct segment_descriptor pcb_fsd;	/* %fs descriptor */
	struct segment_descriptor pcb_gsd; 	/* %gs descriptor */
	void 	*pcb_onfault;		/* copyin/out fault recovery */
	char	*pcb_iomap;		/* I/O permission bitmap */
	struct dbreg	*pcb_dbregs;	/* CPU Debug Registers */
	uint16_t pcb_fpu_dflt_cw;

#define	PCB_DBREGS	0x01
	int	pcb_flags;

	int	not_used[15];

	/* floating point state */
	union savefpu	pcb_savefpu __aligned(64);
	/* **** DO NOT ADD ANYTHING HERE **** */

};
#ifndef __lint__
/* This doesn't really matter, but there is a lot of implied padding */
__CTASSERT(sizeof(struct pcb) - sizeof (union savefpu) == 128);
#endif

#endif /* _I386_PCB_H_ */