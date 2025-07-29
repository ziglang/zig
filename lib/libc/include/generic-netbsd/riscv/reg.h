/* $NetBSD: reg.h,v 1.10 2022/12/13 22:25:08 skrll Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef _RISCV_REG_H_
#define _RISCV_REG_H_

// x0		= 0
// x1		= ra		(return address)		  Caller
// x2		= sp		(stack pointer)			  Callee
// x3		= gp		(global pointer)
// x4		= tp		(thread pointer)
// x5 - x7	= t0 - t2	(temporary)			  Caller
// x8		= s0/fp		(saved register / frame pointer)  Callee
// x9		= s1		(saved register)		  Callee
// x10 - x11	= a0 - a1	(arguments/return values)	  Caller
// x12 - x17	= a2 - a7	(arguments)			  Caller
// x18 - x27	= s2 - s11	(saved registers)		  Callee
// x28 - x31	= t3 - t6	(temporaries)			  Caller

struct reg {	// synced with register_t in <riscv/types.h>
#ifdef _LP64
	__uint64_t r_reg[31]; /* x0 is always 0 */
	__uint64_t r_pc;
#else
	__uint32_t r_reg[31]; /* x0 is always 0 */
	__uint32_t r_pc;
#endif
};

#ifdef _LP64
struct reg32 {	// synced with register_t in <riscv/types.h>
	__uint32_t r_reg[31]; /* x0 is always 0 */
	__uint32_t r_pc;
};
#endif

#define _XREG(n)	((n) - 1)
#define _X_RA		_XREG(1)
#define _X_SP		_XREG(2)
#define _X_GP		_XREG(3)
#define _X_TP		_XREG(4)
#define _X_T0		_XREG(5)
#define _X_T1		_XREG(6)
#define _X_T2		_XREG(7)
#define _X_S0		_XREG(8)
#define _X_S1		_XREG(9)
#define _X_A0		_XREG(10)
#define _X_A1		_XREG(11)
#define _X_A2		_XREG(12)
#define _X_A3		_XREG(13)
#define _X_A4		_XREG(14)
#define _X_A5		_XREG(15)
#define _X_A6		_XREG(16)
#define _X_A7		_XREG(17)
#define _X_S2		_XREG(18)
#define _X_S3		_XREG(19)
#define _X_S4		_XREG(20)
#define _X_S5		_XREG(21)
#define _X_S6		_XREG(22)
#define _X_S7		_XREG(23)
#define _X_S8		_XREG(24)
#define _X_S9		_XREG(25)
#define _X_S10		_XREG(26)
#define _X_S11		_XREG(27)
#define _X_T3		_XREG(28)
#define _X_T4		_XREG(29)
#define _X_T5		_XREG(30)
#define _X_T6		_XREG(31)

// f0 - f7	= ft0 - ft7	(FP temporaries)		  Caller
// following layout is similar to integer registers above
// f8 - f9	= fs0 - fs1	(FP saved registers)		  Callee
// f10 - f11	= fa0 - fa1	(FP arguments/return values)	  Caller
// f12 - f17	= fa2 - fa7	(FP arguments)			  Caller
// f18 - f27	= fs2 - fa11	(FP saved registers)		  Callee
// f28 - f31	= ft8 - ft11	(FP temporaries)		  Caller

/*
 * This fragment is common to <riscv/mcontext.h> and <riscv/reg.h>
 */
#ifndef _BSD_FPREG_T_
union __fpreg {
	__uint64_t u_u64;
	double u_d;
};
#define _BSD_FPREG_T_	union __fpreg
#endif

/*
 * 32 double precision floating point, 1 CSR
 */
struct fpreg {
	_BSD_FPREG_T_	r_fpreg[33];
};
#define r_fcsr		r_fpreg[32].u_u64

#endif /* _RISCV_REG_H_ */