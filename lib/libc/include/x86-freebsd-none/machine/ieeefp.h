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

static __inline fp_rnd_t
fpgetround(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((fp_rnd_t)((_cw & FP_RND_FLD) >> FP_RND_OFF));
}

static __inline fp_rnd_t
fpsetround(fp_rnd_t _m)
{
	fp_rnd_t _p;
	unsigned short _cw, _newcw;

	__fnstcw(&_cw);
	_p = (fp_rnd_t)((_cw & FP_RND_FLD) >> FP_RND_OFF);
	_newcw = _cw & ~FP_RND_FLD;
	_newcw |= (_m << FP_RND_OFF) & FP_RND_FLD;
	__fnldcw(_cw, _newcw);
	return (_p);
}

static __inline fp_prec_t
fpgetprec(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((fp_prec_t)((_cw & FP_PRC_FLD) >> FP_PRC_OFF));
}

static __inline fp_prec_t
fpsetprec(fp_prec_t _m)
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
fpgetmask(void)
{
	unsigned short _cw;

	__fnstcw(&_cw);
	return ((~_cw & FP_MSKS_FLD) >> FP_MSKS_OFF);
}

static __inline fp_except_t
fpsetmask(fp_except_t _m)
{
	fp_except_t _p;
	unsigned short _cw, _newcw;

	__fnstcw(&_cw);
	_p = (~_cw & FP_MSKS_FLD) >> FP_MSKS_OFF;
	_newcw = _cw & ~FP_MSKS_FLD;
	_newcw |= (~_m << FP_MSKS_OFF) & FP_MSKS_FLD;
	__fnldcw(_cw, _newcw);
	return (_p);
}

static __inline fp_except_t
fpgetsticky(void)
{
	unsigned _ex;
	unsigned short _sw;

	__fnstsw(&_sw);
	_ex = (_sw & FP_STKY_FLD) >> FP_STKY_OFF;
	return ((fp_except_t)_ex);
}

static __inline fp_except_t
fpresetsticky(fp_except_t _m)
{
	struct {
		unsigned _cw;
		unsigned _sw;
		unsigned _other[5];
	} _env;
	fp_except_t _p;

	_m &= FP_STKY_FLD >> FP_STKY_OFF;
	_p = fpgetsticky();
	if ((_p & ~_m) == _p)
		return (_p);
	if ((_p & ~_m) == 0) {
		__fnclex();
		return (_p);
	}
	__fnstenv(&_env);
	_env._sw &= ~_m;
	__fldenv(&_env);
	return (_p);
}

#endif /* !_MACHINE_IEEEFP_H_ */