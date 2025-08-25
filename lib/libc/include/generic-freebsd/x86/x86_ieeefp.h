/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 2003 Peter Wemm.
 * Copyright (c) 1990 Andrew Moore, Talke Studio
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 * 	from: @(#) ieeefp.h 	1.0 (Berkeley) 9/23/93
 */

#ifndef _X86_X86_IEEEFP_H_
#define _X86_X86_IEEEFP_H_

/* Deprecated historical FPU control interface */

/*
 * IEEE floating point type, constant and function definitions.
 * XXX: {FP,SSE}*FLD and {FP,SSE}*OFF are undocumented pollution.
 */

/*
 * Rounding modes.
 */
typedef enum {
	FP_RN=0,	/* round to nearest */
	FP_RM,		/* round down towards minus infinity */
	FP_RP,		/* round up towards plus infinity */
	FP_RZ		/* truncate */
} fp_rnd_t;

/*
 * Precision (i.e., rounding precision) modes.
 */
typedef enum {
	FP_PS=0,	/* 24 bit (single-precision) */
	FP_PRS,		/* reserved */
	FP_PD,		/* 53 bit (double-precision) */
	FP_PE		/* 64 bit (extended-precision) */
} fp_prec_t;

#define fp_except_t	int

/*
 * Exception bit masks.
 */
#define FP_X_INV	0x01	/* invalid operation */
#define FP_X_DNML	0x02	/* denormal */
#define FP_X_DZ		0x04	/* zero divide */
#define FP_X_OFL	0x08	/* overflow */
#define FP_X_UFL	0x10	/* underflow */
#define FP_X_IMP	0x20	/* (im)precision */
#define FP_X_STK	0x40	/* stack fault */

/*
 * FPU control word bit-field masks.
 */
#define FP_MSKS_FLD	0x3f	/* exception masks field */
#define FP_PRC_FLD	0x300	/* precision control field */
#define	FP_RND_FLD	0xc00	/* rounding control field */

/*
 * FPU status word bit-field masks.
 */
#define FP_STKY_FLD	0x3f	/* sticky flags field */

/*
 * FPU control word bit-field offsets (shift counts).
 */
#define FP_MSKS_OFF	0	/* exception masks offset */
#define FP_PRC_OFF	8	/* precision control offset */
#define	FP_RND_OFF	10	/* rounding control offset */

/*
 * FPU status word bit-field offsets (shift counts).
 */
#define FP_STKY_OFF	0	/* sticky flags offset */

#define	__fldcw(addr)	__asm __volatile("fldcw %0" : : "m" (*(addr)))
#define	__fldenv(addr)	__asm __volatile("fldenv %0" : : "m" (*(addr)))
#define	__fnclex()	__asm __volatile("fnclex")
#define	__fnstcw(addr)	__asm __volatile("fnstcw %0" : "=m" (*(addr)))
#define	__fnstenv(addr)	__asm __volatile("fnstenv %0" : "=m" (*(addr)))
#define	__fnstsw(addr)	__asm __volatile("fnstsw %0" : "=m" (*(addr)))
#define	__ldmxcsr(addr)	__asm __volatile("ldmxcsr %0" : : "m" (*(addr)))
#define	__stmxcsr(addr)	__asm __volatile("stmxcsr %0" : "=m" (*(addr)))

/*
 * Load the control word.  Be careful not to trap if there is a currently
 * unmasked exception (ones that will become freshly unmasked are not a
 * problem).  This case must be handled by a save/restore of the
 * environment or even of the full x87 state.  Accessing the environment
 * is very inefficient, so only do it when necessary.
 */
static __inline void
__fnldcw(unsigned short _cw, unsigned short _newcw)
{
	struct {
		unsigned _cw;
		unsigned _other[6];
	} _env;
	unsigned short _sw;

	if ((_cw & FP_MSKS_FLD) != FP_MSKS_FLD) {
		__fnstsw(&_sw);
		if (((_sw & ~_cw) & FP_STKY_FLD) != 0) {
			__fnstenv(&_env);
			_env._cw = _newcw;
			__fldenv(&_env);
			return;
		}
	}
	__fldcw(&_newcw);
}

#endif/* _X86_X86_IEEEFP_H_ */