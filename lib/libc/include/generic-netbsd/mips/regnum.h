/*	$NetBSD: regnum.h,v 1.12 2020/07/26 08:08:41 simonb Exp $	*/

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
 * from: Utah Hdr: reg.h 1.1 90/07/09
 *
 *	@(#)reg.h	8.2 (Berkeley) 1/11/94
 */

/*
 * Location of the users' stored
 * registers relative to ZERO.
 * Usage is p->p_regs[XX].
 */
#define	_R_ZERO		0		/* hardware zero */
#define	_R_AST		1		/* caller-saved */
#define	_R_V0		2		/* caller-saved */
#define	_R_V1		3		/* caller-saved */
#define	_R_A0		4		/* caller-saved */
#define	_R_A1		5		/* caller-saved */
#define	_R_A2		6		/* caller-saved */
#define	_R_A3		7		/* caller-saved */
#if defined(__mips_n32) || defined(__mips_n64)
#define	_R_A4		8		/* caller-saved */
#define	_R_A5		9		/* caller-saved */
#define	_R_A6		10		/* caller-saved */
#define	_R_A7		11		/* caller-saved */
#define	_R_T0		12		/* caller-saved */
#define	_R_T1		13		/* caller-saved */
#define	_R_T2		14		/* caller-saved */
#define	_R_T3		15		/* caller-saved */
#else
#define	_R_T0		8		/* caller-saved */
#define	_R_T1		9		/* caller-saved */
#define	_R_T2		10		/* caller-saved */
#define	_R_T3		11		/* caller-saved */
#define	_R_T4		12		/* caller-saved */
#define	_R_T5		13		/* caller-saved */
#define	_R_T6		14		/* caller-saved */
#define	_R_T7		15		/* caller-saved */
#endif /* __mips_n32 || __mips_n64 */
#define	_R_S0		16		/* CALLEE-saved */
#define	_R_S1		17		/* CALLEE-saved */
#define	_R_S2		18		/* CALLEE-saved */
#define	_R_S3		19		/* CALLEE-saved */
#define	_R_S4		20		/* CALLEE-saved */
#define	_R_S5		21		/* CALLEE-saved */
#define	_R_S6		22		/* CALLEE-saved */
#define	_R_S7		23		/* CALLEE-saved */
#define	_R_T8		24		/* caller-saved */
#define	_R_T9		25		/* caller-saved */
#define	_R_K0		26		/* kernel reserved */
#define	_R_K1		27		/* kernel reserved */
#define	_R_GP		28		/* CALLEE-saved */
#define	_R_SP		29		/* CALLEE-saved */
#define	_R_S8		30		/* CALLEE-saved */
#define	_R_RA		31		/* caller-saved */
#define	_R_SR		32
#define	_R_PS		_R_SR	/* alias for SR */

/* See <mips/regdef.h> for an explanation. */
#if defined(__mips_n32) || defined(__mips_n64)
#define	_R_TA0		8
#define	_R_TA1		9
#define	_R_TA2		10
#define	_R_TA3		11
#else
#define	_R_TA0		12
#define	_R_TA1		13
#define	_R_TA2		14
#define	_R_TA3		15
#endif /* __mips_n32 || __mips_n64 */

#define	_R_MULLO	33
#define	_R_MULHI	34
#define	_R_BADVADDR	35
#define	_R_CAUSE	36
#define	_R_PC		37

#define	_FPBASE		(_R_PC + 1)
#define	_R_F0		(_FPBASE+0)
#define	_R_F1		(_FPBASE+1)
#define	_R_F2		(_FPBASE+2)
#define	_R_F3		(_FPBASE+3)
#define	_R_F4		(_FPBASE+4)
#define	_R_F5		(_FPBASE+5)
#define	_R_F6		(_FPBASE+6)
#define	_R_F7		(_FPBASE+7)
#define	_R_F8		(_FPBASE+8)
#define	_R_F9		(_FPBASE+9)
#define	_R_F10		(_FPBASE+10)
#define	_R_F11		(_FPBASE+11)
#define	_R_F12		(_FPBASE+12)
#define	_R_F13		(_FPBASE+13)
#define	_R_F14		(_FPBASE+14)
#define	_R_F15		(_FPBASE+15)
#define	_R_F16		(_FPBASE+16)
#define	_R_F17		(_FPBASE+17)
#define	_R_F18		(_FPBASE+18)
#define	_R_F19		(_FPBASE+19)
#define	_R_F20		(_FPBASE+20)
#define	_R_F21		(_FPBASE+21)
#define	_R_F22		(_FPBASE+22)
#define	_R_F23		(_FPBASE+23)
#define	_R_F24		(_FPBASE+24)
#define	_R_F25		(_FPBASE+25)
#define	_R_F26		(_FPBASE+26)
#define	_R_F27		(_FPBASE+27)
#define	_R_F28		(_FPBASE+28)
#define	_R_F29		(_FPBASE+29)
#define	_R_F30		(_FPBASE+30)
#define	_R_F31		(_FPBASE+31)
#define	_R_FSR		(_FPBASE+32)

#define	_R_DSPBASE	(_R_FSR + 1)
#define	_R_MULLO1	(_R_DSPBASE + 0)
#define	_R_MULHI1	(_R_DSPBASE + 1)
#define	_R_MULLO2	(_R_DSPBASE + 2)
#define	_R_MULHI2	(_R_DSPBASE + 3)
#define	_R_MULLO3	(_R_DSPBASE + 4)
#define	_R_MULHI3	(_R_DSPBASE + 5)
#define	_R_DSPCTL	(_R_DSPBASE + 6)