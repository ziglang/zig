/*	$NetBSD: ptrace.h,v 1.17 2020/12/14 01:58:48 rin Exp $	*/

/*
 * Copyright (c) 1995 Frank Lancaster
 * Copyright (c) 1995 Tools GmbH
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
 *      This product includes software developed by TooLs GmbH.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <arm/cdefs.h>

/*
 * arm-dependent ptrace definitions
 */
#if 0
/* Exposed to userland for NetBSD 1.6 to 9. Do not reuse for other purpose. */
#define PT_STEP		(PT_FIRSTMACH + 0) /* Not implemented */
#endif
#define	PT_GETREGS	(PT_FIRSTMACH + 1)
#define	PT_SETREGS	(PT_FIRSTMACH + 2)
/* 3 and 4 are for FPE registers */
#define	PT_GETFPREGS	(PT_FIRSTMACH + 5)
#define	PT_SETFPREGS	(PT_FIRSTMACH + 6)
#if 0
/* Exposed to userland for NetBSD 8 to 9. Do not reuse for other purpose. */
#define PT_SETSTEP	(PT_FIRSTMACH + 7) /* Not implemented */
#define PT_CLEARSTEP	(PT_FIRSTMACH + 8) /* Not implemented */
#endif

#define PT_MACHDEP_STRINGS \
	"n/a PT_STEP", \
	"PT_GETREGS", \
	"PT_SETREGS", \
	"old PT_GETFPREGS", \
	"old PT_SETFPREGS", \
	"PT_GETFPREGS", \
	"PT_SETFPREGS", \
	"n/a PT_SETSTEP", \
	"n/a PT_CLEARSTEP",

#include <machine/reg.h>
#define PTRACE_REG_PC(_r)		(_r)->r_pc
#define PTRACE_REG_FP(_r)		(_r)->r[11]
#define PTRACE_REG_SET_PC(_r, _v)	(_r)->r_pc = (_v)
#define PTRACE_REG_SP(_r)		(_r)->r_sp
#define PTRACE_REG_INTRV(_r)		(_r)->r[0]

#define PTRACE_ILLEGAL_ASM	__asm __volatile ("udf #0" : : : "memory")

#if defined(__ARMEL__) || defined(_ARM_ARCH_BE8)
#define PTRACE_BREAKPOINT	((const uint8_t[]) { 0xfe, 0xde, 0xff, 0xe7 })
#else
#define PTRACE_BREAKPOINT	((const uint8_t[]) { 0xe7, 0xff, 0xde, 0xfe })
#endif

#ifdef _ARM_ARCH_BE8
#define PTRACE_BREAKPOINT_INSN	0xfedeffe7
#else
#define PTRACE_BREAKPOINT_INSN	0xe7ffdefe
#endif

#define PTRACE_BREAKPOINT_ASM	__asm __volatile (".word " ___STRING(PTRACE_BREAKPOINT_INSN) )
#define PTRACE_BREAKPOINT_SIZE	4