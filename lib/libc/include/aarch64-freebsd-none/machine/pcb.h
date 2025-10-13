/*-
 * Copyright (c) 2001 Jake Burkholder.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifdef __arm__
#include <arm/pcb.h>
#else /* !__arm__ */

#ifndef	_MACHINE_PCB_H_
#define	_MACHINE_PCB_H_

#ifndef LOCORE

#include <machine/debug_monitor.h>
#include <machine/vfp.h>

struct trapframe;

/* The first register in pcb_x is x19 */
#define	PCB_X_START	19

#define	PCB_X19		0
#define	PCB_X20		1
#define	PCB_FP		10
#define	PCB_LR		11

struct pcb {
	uint64_t	pcb_x[12];
	/* These two need to be in order as we access them together */
	uint64_t	pcb_sp;
	uint64_t	pcb_tpidr_el0;
	uint64_t	pcb_tpidrro_el0;

	/* Fault handler, the error value is passed in x0 */
	vm_offset_t	pcb_onfault;

	u_int		pcb_flags;
#define	PCB_SINGLE_STEP_SHIFT	0
#define	PCB_SINGLE_STEP		(1 << PCB_SINGLE_STEP_SHIFT)
	u_int		pcb_sve_len;	/* The SVE vector length */

	struct vfpstate	*pcb_fpusaved;
	int		pcb_fpflags;
#define	PCB_FP_STARTED	0x00000001
#define	PCB_FP_SVEVALID	0x00000002
#define	PCB_FP_KERN	0x40000000
#define	PCB_FP_NOSAVE	0x80000000
/* The bits passed to userspace in get_fpcontext */
#define	PCB_FP_USERMASK	(PCB_FP_STARTED | PCB_FP_SVEVALID)
	u_int		pcb_vfpcpu;	/* Last cpu this thread ran VFP code */
	void		*pcb_svesaved;
	uint64_t	pcb_reserved[4];

	/*
	 * The userspace VFP state. The pcb_fpusaved pointer will point to
	 * this unless the kernel has allocated a VFP context.
	 * Place last to simplify the asm to access the rest if the struct.
	 */
	struct vfpstate	pcb_fpustate;

	struct debug_monitor_state pcb_dbg_regs;
};

#ifdef _KERNEL
void	makectx(struct trapframe *tf, struct pcb *pcb);
void	savectx(struct pcb *pcb) __returns_twice;
#endif

#endif /* !LOCORE */

#endif /* !_MACHINE_PCB_H_ */

#endif /* !__arm__ */