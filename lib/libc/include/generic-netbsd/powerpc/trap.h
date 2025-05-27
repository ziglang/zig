/*	$NetBSD: trap.h,v 1.14 2020/07/06 09:34:17 rin Exp $	*/

/*
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

#ifndef	_POWERPC_TRAP_H_
#define	_POWERPC_TRAP_H_

#define	EXC_RSVD	0x0000		/* Reserved */
#define	EXC_RST		0x0100		/* Reset; all but IBM4xx */
#define	EXC_MCHK	0x0200		/* Machine Check */
#define	EXC_DSI		0x0300		/* Data Storage Interrupt */
#define	EXC_ISI		0x0400		/* Instruction Storage Interrupt */
#define	EXC_EXI		0x0500		/* External Interrupt */
#define	EXC_ALI		0x0600		/* Alignment Interrupt */
#define	EXC_PGM		0x0700		/* Program Interrupt */
#define	EXC_FPU		0x0800		/* Floating-point Unavailable */
#define	EXC_DECR	0x0900		/* Decrementer Interrupt */
#define	EXC_SC		0x0c00		/* System Call */
#define	EXC_TRC		0x0d00		/* Trace */
#define	EXC_FPA		0x0e00		/* Floating-point Assist */

/* The following are only available on the 601: */
#define EXC_IOC         0x0a00          /* I/O Controller Interface Exception */
#define	EXC_RUNMODETRC	0x2000		/* Run Mode/Trace Exception */

/* The following are only available on 7400(G4): */
#define	EXC_VEC		0x0f20		/* AltiVec Unavailable */
#define	EXC_VECAST	0x1600		/* AltiVec Assist */

/* The following are only available on 604/750/7400: */
#define	EXC_PERF	0x0f00		/* Performance Monitoring */
#define	EXC_BPT		0x1300		/* Instruction Breakpoint */
#define	EXC_SMI		0x1400		/* System Management Interrupt */

/* The following are only available on 750/7400: */
#define	EXC_THRM	0x1700		/* Thermal Management Interrupt */

/* And these are only on the 603: */
#define	EXC_IMISS	0x1000		/* Instruction translation miss */
#define	EXC_DLMISS	0x1100		/* Data load translation miss */
#define	EXC_DSMISS	0x1200		/* Data store translation miss */

/* The following are only available on 405 (and 403?) */
#define	EXC_CII		0x0100		/* Critical Input Interrupt */
#define	EXC_PIT		0x1000		/* Programmable Interval Timer */
#define	EXC_FIT		0x1010		/* Fixed Interval Timer */
#define	EXC_WDOG	0x1020		/* Watchdog Timer */
#define	EXC_DTMISS	0x1100		/* Data TLB Miss */
#define	EXC_ITMISS	0x1200		/* Instruction TLB Miss */
#define	EXC_DEBUG	0x2000		/* Debug trap */

/* The following are only available on mpc8xx */
#define	EXC_SWEMUL	0x1000		/* Software Emulation */
#define	EXC_ITMISS_8XX	0x1100		/* Instruction TLB Miss */
#define	EXC_DTMISS_8XX	0x1200		/* Data TLB Miss */
#define	EXC_ITERROR	0x1300		/* Instruction TLB Error */
#define	EXC_DTERROR	0x1400		/* Data TLB Error */
#define	EXC_DBREAK	0x1c00		/* data breakpoint */
#define	EXC_IBREAK	0x1d00		/* instructin breakpoint */

/* The following are only present on 64 bit PPC implementations */
#define EXC_DSEG	0x380
#define EXC_ISEG	0x480

/* The IBM 970x define the VMX assist exection to be 0x1700 */
#define EXC_970_VECAST	0x1700

#define	EXC_LAST	0x2f00		/* Last possible exception vector */

#define	EXC_AST		0x3000		/* Fake AST vector */

/* Trap was in user mode */
#define	EXC_USER	0x10000

/* Exception vector base address when MSR[IP] is set */
#define EXC_HIGHVEC	0xfff00000

/*
 * EXC_ALI sets bits in the DSISR and DAR to provide enough
 * information to recover from the unaligned access without needing to
 * parse the offending instruction. This includes certain bits of the
 * opcode, and information about what registers are used. The opcode
 * indicator values below come from Appendix F of Book III of "The
 * PowerPC Architecture".
 */

#define EXC_ALI_OPCODE_INDICATOR(dsisr) ((dsisr >> 10) & 0x7f)

#define EXC_ALI_LWARX_LWZ  0x00
#define EXC_ALI_LDARX      0x01
#define EXC_ALI_STW        0x02
#define EXC_ALI_LHZ        0x04
#define EXC_ALI_LHA        0x05
#define EXC_ALI_STH        0x06
#define EXC_ALI_LMW        0x07
#define EXC_ALI_LFS        0x08
#define EXC_ALI_LFD	0x09
#define EXC_ALI_STFS       0x0a
#define EXC_ALI_STFD	0x0b
#define EXC_ALI_LD_LDU_LWA 0x0d
#define EXC_ALI_STD_STDU   0x0f
#define EXC_ALI_LWZU       0x10
#define EXC_ALI_STWU       0x12
#define EXC_ALI_LHZU       0x14
#define EXC_ALI_LHAU       0x15
#define EXC_ALI_STHU       0x16
#define EXC_ALI_STMW       0x17
#define EXC_ALI_LFSU       0x18
#define EXC_ALI_LFDU       0x19
#define EXC_ALI_STFSU      0x1a
#define EXC_ALI_STFDU      0x1b
#define EXC_ALI_LDX        0x20
#define EXC_ALI_STDX       0x22
#define EXC_ALI_LWAX       0x25
#define EXC_ALI_LSWX       0x28
#define EXC_ALI_LSWI       0x29
#define EXC_ALI_STSWX      0x2a
#define EXC_ALI_STSWI      0x2b
#define EXC_ALI_LDUX       0x30
#define EXC_ALI_STDUX      0x32
#define EXC_ALI_LWAUX      0x35
#define EXC_ALI_STWCX      0x42  /* stwcx. */
#define EXC_ALI_STDCX      0x43  /* stdcx. */
#define EXC_ALI_LWBRX      0x48
#define EXC_ALI_STWBRX     0x4a
#define EXC_ALI_LHBRX      0x4c
#define EXC_ALI_STHBRX     0x4e
#define EXC_ALI_ECIWX      0x54
#define EXC_ALI_ECOWX      0x56
#define EXC_ALI_DCBZ	0x5f
#define EXC_ALI_LWZX       0x60
#define EXC_ALI_STWX       0x62
#define EXC_ALI_LHZX       0x64
#define EXC_ALI_LHAX       0x65
#define EXC_ALI_STHX       0x66
#define EXC_ALI_LSFX       0x68
#define EXC_ALI_LDFX       0x69
#define EXC_ALI_STFSX      0x6a
#define EXC_ALI_STFDX      0x6b
#define EXC_ALI_STFIWX     0x6f
#define EXC_ALI_LWZUX      0x70
#define EXC_ALI_STWUX      0x72
#define EXC_ALI_LHZUX      0x74
#define EXC_ALI_LHAUX      0x75
#define EXC_ALI_STHUX      0x76
#define EXC_ALI_LFSUX      0x78
#define EXC_ALI_LFDUX      0x79
#define EXC_ALI_STFSUX     0x7a
#define EXC_ALI_STFDUX     0x7b

/* Macros to extract register information */
#define EXC_ALI_RST(dsisr) ((dsisr >> 5) & 0x1f)   /* source or target */
#define EXC_ALI_RA(dsisr) (dsisr & 0x1f)

/* Helper defines to classify EXC_ALI_ */
#define DSI_OP_ZERO      0x0001
#define DSI_OP_UPDATE    0x0002
#define DSI_OP_INDEXED   0x0004
#define DSI_OP_ALGEBRAIC 0x0008
#define DSI_OP_REVERSED  0x0010

#endif	/* _POWERPC_TRAP_H_ */