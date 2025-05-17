/*	$NetBSD: ptrace.h,v 1.19 2021/03/18 23:18:36 simonb Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)ptrace.h	8.1 (Berkeley) 6/10/93
 */

/*
 * Mips-dependent ptrace definitions.
 *
 */

#ifndef _MIPS_PTRACE_H_
#define	_MIPS_PTRACE_H_

/* MIPS PT_STEP PT_FIRSTMACH+0 might be defined by a port specific header */
#define	PT_GETREGS	(PT_FIRSTMACH + 1)
#define	PT_SETREGS	(PT_FIRSTMACH + 2)

#define	PT_GETFPREGS	(PT_FIRSTMACH + 3)
#define	PT_SETFPREGS	(PT_FIRSTMACH + 4)

#ifdef PT_STEP
#define	PT_SETSTEP	(PT_FIRSTMACH + 5)
#define	PT_CLEARSTEP	(PT_FIRSTMACH + 6)
#endif

#define	PT_MACHDEP_STRINGS \
	"PT_STEP", \
	"PT_GETREGS", \
	"PT_SETREGS", \
	"PT_GETFPREGS", \
	"PT_SETFPREGS", \
	"PT_SETSTEP", \
	"PT_CLEARSTEP",

#include <machine/reg.h>
#define	PTRACE_REG_PC(r)	(r)->r_regs[35]
#define	PTRACE_REG_FP(r)	(r)->r_regs[30]
#define	PTRACE_REG_SET_PC(r, v)	(r)->r_regs[35] = (v)
#define	PTRACE_REG_SP(r)	(r)->r_regs[29]
#define	PTRACE_REG_INTRV(r)	(r)->r_regs[2]

/*
 * The sigrie is defined in the MIPS32r6 and MIPS64r6 specs to
 * generate a Reserved Instruction trap but uses a previously
 * reserved instruction encoding and is thus both backwards and
 * forwards compatible.
 */
#define	PTRACE_ILLEGAL_ASM	do {					\
		asm volatile(						\
			".set	push;		"			\
			".set	mips32r6;	"			\
			"sigrie	0;		"			\
			".set	pop;		"			\
		);							\
	} while (0);

#define	PTRACE_BREAKPOINT	((const uint8_t[]) { 0x00, 0x00, 0x00, 0x0d })
#define	PTRACE_BREAKPOINT_ASM	__asm __volatile("break")
#define	PTRACE_BREAKPOINT_SIZE	4

/*
 * Glue for gdb: map NetBSD register names to legacy ptrace register names
 */
#define	GPR_BASE 0

#ifndef JB_PC
#define	JB_PC	2	/* pc is at ((long *)jmp_buf)[2] */
#endif

#include <machine/reg.h>	/* Historically in sys/ptrace.h */
#include <machine/regnum.h>	/* real register names */

#endif	 /* _MIPS_PTRACE_H_ */