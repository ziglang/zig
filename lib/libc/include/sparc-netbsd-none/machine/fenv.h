/*	$NetBSD: fenv.h,v 1.2 2017/01/14 12:00:13 martin Exp $	*/

/*-
 * Copyright (c) 2004-2005 David Schultz <das@FreeBSD.ORG>
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
 *
 * $FreeBSD$
 */

#ifndef	_SPARC_FENV_H_
#define	_SPARC_FENV_H_

#include <sys/stdint.h>

#ifdef __arch64__
typedef	uint64_t	fenv_t;
typedef	uint64_t	fexcept_t;
#else
typedef	uint32_t	fenv_t;
typedef	uint32_t	fexcept_t;
#endif

/*
 * Exception flags
 *
 * Symbols are defined in such a way, to correspond to the accrued
 * exception bits (aexc) fields of FSR.
 */
#define	FE_INEXACT      0x00000020	/* 0000100000 */
#define	FE_DIVBYZERO    0x00000040	/* 0001000000 */
#define	FE_UNDERFLOW    0x00000080	/* 0010000000 */
#define	FE_OVERFLOW     0x00000100	/* 0100000000 */
#define	FE_INVALID	0x00000200	/* 1000000000 */

#define	FE_ALL_EXCEPT	(FE_DIVBYZERO | FE_INEXACT | \
    FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW)

/*
 * Rounding modes
 *
 * We can't just use the hardware bit values here, because that would
 * make FE_UPWARD and FE_DOWNWARD negative, which is not allowed.
 */
#define	FE_TONEAREST	0	/* round to nearest representable number */
#define	FE_TOWARDZERO	1	/* round to zero (truncate) */
#define	FE_UPWARD	2	/* round toward positive infinity */
#define	FE_DOWNWARD	3	/* round toward negative infinity */
#define	_ROUND_MASK	(FE_TONEAREST | FE_DOWNWARD | \
    FE_UPWARD | FE_TOWARDZERO)
#define	_ROUND_SHIFT	30

__BEGIN_DECLS

/* Default floating-point environment */
extern const fenv_t	__fe_dfl_env;
#define	FE_DFL_ENV	(&__fe_dfl_env)

/* We need to be able to map status flag positions to mask flag positions */
#define	_FPUSW_SHIFT	18
#define	_ENABLE_MASK	(FE_ALL_EXCEPT << _FPUSW_SHIFT)

__END_DECLS

#endif	/* !_SPARC_FENV_H_ */