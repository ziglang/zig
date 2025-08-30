/*	pcb.h,v 1.14.22.2 2007/11/06 23:15:05 matt Exp	*/

/*
 * Copyright (c) 2001 Matt Thomas <matt@3am-software.com>.
 * Copyright (c) 1994 Mark Brinicombe.
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
 *	This product includes software developed by the RiscBSD team.
 * 4. The name "RiscBSD" nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY RISCBSD ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL RISCBSD OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_ARM_PCB_H_
#define	_ARM_PCB_H_

#include <machine/frame.h>

#include <arm/arm32/pte.h>
#include <arm/reg.h>

struct pcb_faultinfo {
	void *pfi_faultptep;
	vaddr_t pfi_faultaddr;
	u_int pfi_repeats;
	pid_t pfi_lastpid;
	uint8_t pfi_faulttype;
};

#define	pcb_ksp		pcb_sp

struct pcb {
	/*
	 * WARNING!
	 * cpuswitchto.S relies on pcb_r8 being quad-aligned
	 * (due to the use of "strd" when compiled for XSCALE)
	 */
	u_int	pcb_r8 __aligned(8);		/* used */
	u_int	pcb_r9;				/* used */
	u_int	pcb_r10;			/* used */
	u_int	pcb_r11;			/* used */
	u_int	pcb_r12;			/* used */
	u_int	pcb_sp;				/* used */
	u_int	pcb_lr;
	u_int	pcb_pc;

	/*
	 * ARMv6 has two user thread/process id registers which can hold
	 * any 32bit quanttiies.
	 */
	u_int	pcb_user_pid_rw;		/* p15, 0, Rd, c13, c0, 2 */
	u_int	pcb_user_pid_ro;		/* p15, 0, Rd, c13, c0, 3 */

	void *	pcb_onfault;			/* On fault handler */
	struct	vfpreg pcb_vfp;			/* VFP registers */
	struct	vfpreg pcb_kernel_vfp;		/* kernel VFP state */
	struct  pcb_faultinfo pcb_faultinfo;
};

/*
 * No additional data for core dumps.
 */
struct md_coredump {
	int	md_empty;
};

#endif	/* _ARM_PCB_H_ */