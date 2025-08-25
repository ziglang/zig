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

#ifndef _MACHINE_IEEEFP_H_
#define _MACHINE_IEEEFP_H_

/* Deprecated historical FPU control interface */

#include <x86/x86_ieeefp.h>

/*
 * IEEE floating point type, constant and function definitions.
 * XXX: {FP,SSE}*FLD and {FP,SSE}*OFF are undocumented pollution.
 */

/*
 * SSE mxcsr register bit-field masks.
 */
#define	SSE_STKY_FLD	0x3f	/* exception flags */
#define	SSE_DAZ_FLD	0x40	/* Denormals are zero */
#define	SSE_MSKS_FLD	0x1f80	/* exception masks field */
#define	SSE_RND_FLD	0x6000	/* rounding control */
#define	SSE_FZ_FLD	0x8000	/* flush to zero on underflow */

/*
 * SSE mxcsr register bit-field offsets (shift counts).
 */
#define	SSE_STKY_OFF	0	/* exception flags offset */
#define	SSE_DAZ_OFF	6	/* DAZ exception mask offset */
#define	SSE_MSKS_OFF	7	/* other exception masks offset */
#define	SSE_RND_OFF	13	/* rounding control offset */
#define	SSE_FZ_OFF	15	/* flush to zero offset */

/*
 * General notes about conflicting SSE vs FP status bits.
 * This code assumes that software will not fiddle with the control
 * bits of the SSE and x87 in such a way to get them out of sync and
 * still expect this to work.  Break this at your peril.
 * Because I based this on the i386 port, the x87 state is used for
 * the fpget*() functions, and is shadowed into the SSE state for
 * the fpset*() functions.  For dual source fpget*() functions, I
 * merge the two together.  I think.
 */

static __inline fp_rnd_t
__fpgetround(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((fp_rnd_t)((_cw & FP_RND_FLD) >> FP_RND_OFF));
}

static __inline fp_rnd_t
__fpsetround(fp_rnd_t _m)
{
	fp_rnd_t _p;
	unsigned _mxcsr;
	unsigned short _cw, _newcw;

	__fnstcw(&_cw);
	_p = (fp_rnd_t)((_cw & FP_RND_FLD) >> FP_RND_OFF);
	_newcw = _cw & ~FP_RND_FLD;
	_newcw |= (_m << FP_RND_OFF) & FP_RND_FLD;
	__fnldcw(_cw, _newcw);
	__stmxcsr(&_mxcsr);
	_mxcsr &= ~SSE_RND_FLD;
	_mxcsr |= (_m << SSE_RND_OFF) & SSE_RND_FLD;
	__ldmxcsr(&_mxcsr);
	return (_p);
}

/*
 * Get or set the rounding precision for x87 arithmetic operations.
 * There is no equivalent SSE mode or control.
 */

static __inline fp_prec_t
__fpgetprec(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((fp_prec_t)((_cw & FP_PRC_FLD) >> FP_PRC_OFF));
}

static __inline fp_prec_t
__fpsetprec(fp_prec_t _m)
{
	fp_prec_t _p;
	unsigned short _cw, _newcw;

	__fnstcw(&_cw);
	_p = (fp_prec_t)((_cw & FP_PRC_FLD) >> FP_PRC_OFF);
	_newcw = _cw & ~FP_PRC_FLD;
	_newcw |= (_m << FP_PRC_OFF) & FP_PRC_FLD;
	__fnldcw(_cw, _newcw);
	return (_p);
}

/*
 * Get or set the exception mask.
 * Note that the x87 mask bits are inverted by the API -- a mask bit of 1
 * means disable for x87 and SSE, but for fp*mask() it means enable.
 */

static __inline fp_except_t
__fpgetmask(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((~_cw & FP_MSKS_FLD) >> FP_MSKS_OFF);
}

static __inline fp_except_t
__fpsetmask(fp_except_t _m)
{
	fp_except_t _p;
	unsigned _mxcsr;
	unsigned short _cw, _newcw;

	__fnstcw(&_cw);
	_p = (~_cw & FP_MSKS_FLD) >> FP_MSKS_OFF;
	_newcw = _cw & ~FP_MSKS_FLD;
	_newcw |= (~_m << FP_MSKS_OFF) & FP_MSKS_FLD;
	__fnldcw(_cw, _newcw);
	__stmxcsr(&_mxcsr);
	/* XXX should we clear non-ieee SSE_DAZ_FLD and SSE_FZ_FLD ? */
	_mxcsr &= ~SSE_MSKS_FLD;
	_mxcsr |= (~_m << SSE_MSKS_OFF) & SSE_MSKS_FLD;
	__ldmxcsr(&_mxcsr);
	return (_p);
}

static __inline fp_except_t
__fpgetsticky(void)
{
	unsigned _ex, _mxcsr;
	unsigned short _sw;

	__fnstsw(&_sw);
	_ex = (_sw & FP_STKY_FLD) >> FP_STKY_OFF;
	__stmxcsr(&_mxcsr);
	_ex |= (_mxcsr & SSE_STKY_FLD) >> SSE_STKY_OFF;
	return ((fp_except_t)_ex);
}

#if !defined(__IEEEFP_NOINLINES__)

#define	fpgetmask()	__fpgetmask()
#define	fpgetprec()	__fpgetprec()
#define	fpgetround()	__fpgetround()
#define	fpgetsticky()	__fpgetsticky()
#define	fpsetmask(m)	__fpsetmask(m)
#define	fpsetprec(m)	__fpsetprec(m)
#define	fpsetround(m)	__fpsetround(m)

#else /* __IEEEFP_NOINLINES__ */

/* Augment the userland declarations. */
__BEGIN_DECLS
extern fp_rnd_t    fpgetround(void);
extern fp_rnd_t    fpsetround(fp_rnd_t);
extern fp_except_t fpgetmask(void);
extern fp_except_t fpsetmask(fp_except_t);
extern fp_except_t fpgetsticky(void);
extern fp_except_t fpsetsticky(fp_except_t);
fp_prec_t	fpgetprec(void);
fp_prec_t	fpsetprec(fp_prec_t);
__END_DECLS

#endif /* !__IEEEFP_NOINLINES__ */

#endif /* !_MACHINE_IEEEFP_H_ */