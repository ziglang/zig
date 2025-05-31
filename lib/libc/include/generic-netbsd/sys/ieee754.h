/*	$NetBSD: ieee754.h,v 1.17 2020/04/16 22:13:51 christos Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)ieee.h	8.1 (Berkeley) 6/11/93
 */
#ifndef _SYS_IEEE754_H_
#define _SYS_IEEE754_H_

/*
 * NOTICE: This is not a standalone file.  To use it, #include it in
 * your port's ieee.h header.
 */

#include <machine/endian.h>

/*
 * <sys/ieee754.h> defines the layout of IEEE 754 floating point types.
 * Only single-precision and double-precision types are defined here;
 * 128-bit long doubles are defined here IFF __HAVE_LONG_DOUBLE equals 128.
 * Otherwise extended types, if available, are defined in the machine-dependent
 * header.
 */

/*
 * Define the number of bits in each fraction and exponent.
 *
 *		     k	         k+1
 * Note that  1.0 x 2  == 0.1 x 2      and that denorms are represented
 *
 *					  (-exp_bias+1)
 * as fractions that look like 0.fffff x 2             .  This means that
 *
 *			 -126
 * the number 0.10000 x 2    , for instance, is the same as the normalized
 *
 *		-127			   -128
 * float 1.0 x 2    .  Thus, to represent 2    , we need one leading zero
 *
 *				  -129
 * in the fraction; to represent 2    , we need two, and so on.  This
 *
 *						     (-exp_bias-fracbits+1)
 * implies that the smallest denormalized number is 2
 *
 * for whichever format we are talking about: for single precision, for
 *
 *						-126		-149
 * instance, we get .00000000000000000000001 x 2    , or 1.0 x 2    , and
 *
 * -149 == -127 - 23 + 1.
 */
#define	SNG_EXPBITS	8
#define	SNG_FRACBITS	23

struct ieee_single {
#if _BYTE_ORDER == _BIG_ENDIAN
	unsigned int	sng_sign:1;
	unsigned int	sng_exp:SNG_EXPBITS;
	unsigned int	sng_frac:SNG_FRACBITS;
#else
	unsigned int	sng_frac:SNG_FRACBITS;
	unsigned int	sng_exp:SNG_EXPBITS;
	unsigned int	sng_sign:1;
#endif
};

#define	DBL_EXPBITS	11
#define	DBL_FRACHBITS	20
#define	DBL_FRACLBITS	32
#define	DBL_FRACBITS	(DBL_FRACHBITS + DBL_FRACLBITS)

struct ieee_double {
#if _BYTE_ORDER == _BIG_ENDIAN
	unsigned int	dbl_sign:1;
	unsigned int	dbl_exp:DBL_EXPBITS;
	unsigned int	dbl_frach:DBL_FRACHBITS;
	unsigned int	dbl_fracl:DBL_FRACLBITS;
#else
	unsigned int	dbl_fracl:DBL_FRACLBITS;
	unsigned int	dbl_frach:DBL_FRACHBITS;
	unsigned int	dbl_exp:DBL_EXPBITS;
	unsigned int	dbl_sign:1;
#endif
};

#if __HAVE_LONG_DOUBLE + 0 == 128

#define	EXT_EXPBITS	15
#define EXT_FRACHBITS	48
#define	EXT_FRACLBITS	64
#define	EXT_FRACBITS	(EXT_FRACLBITS + EXT_FRACHBITS)

#define	EXT_TO_ARRAY32(u, a) do {				\
	(a)[0] = (uint32_t)((u).extu_ext.ext_fracl >>  0);	\
	(a)[1] = (uint32_t)((u).extu_ext.ext_fracl >> 32);	\
	(a)[2] = (uint32_t)((u).extu_ext.ext_frach >>  0);	\
	(a)[3] = (uint32_t)((u).extu_ext.ext_frach >> 32);	\
} while(/*CONSTCOND*/0)

struct ieee_ext {
#if _BYTE_ORDER == _BIG_ENDIAN
	uint64_t ext_sign:1;
	uint64_t ext_exp:EXT_EXPBITS;
	uint64_t ext_frach:EXT_FRACHBITS;
	uint64_t ext_fracl;
#else
	uint64_t ext_fracl;
	uint64_t ext_frach:EXT_FRACHBITS;
	uint64_t ext_exp:EXT_EXPBITS;
	uint64_t ext_sign:1;
#endif
};
#endif /* __HAVE_LONG_DOUBLE == 128 */

/*
 * Floats whose exponent is in [1..INFNAN) (of whatever type) are
 * `normal'.  Floats whose exponent is INFNAN are either Inf or NaN.
 * Floats whose exponent is zero are either zero (iff all fraction
 * bits are zero) or subnormal values.
 *
 * At least one `signalling NaN' and one `quiet NaN' value must be
 * implemented.  It is left to the architecture to specify how to
 * distinguish between these.
 */
#define	SNG_EXP_INFNAN	255
#define	DBL_EXP_INFNAN	2047
#if __HAVE_LONG_DOUBLE + 0 == 128
#define	EXT_EXP_INFNAN	0x7fff
#endif

/*
 * Exponent biases.
 */
#define	SNG_EXP_BIAS	127
#define	DBL_EXP_BIAS	1023
#if __HAVE_LONG_DOUBLE + 0 == 128
#define	EXT_EXP_BIAS	16383
#endif

/*
 * Convenience data structures.
 */
union ieee_single_u {
	float			sngu_f;
	struct ieee_single	sngu_sng;
};

#define	sngu_sign	sngu_sng.sng_sign
#define	sngu_exp	sngu_sng.sng_exp
#define	sngu_frac	sngu_sng.sng_frac
#define	SNGU_ZEROFRAC_P(u)	((u).sngu_frac != 0)

union ieee_double_u {
	double			dblu_d;
	struct ieee_double	dblu_dbl;
};

#define	dblu_sign	dblu_dbl.dbl_sign
#define	dblu_exp	dblu_dbl.dbl_exp
#define	dblu_frach	dblu_dbl.dbl_frach
#define	dblu_fracl	dblu_dbl.dbl_fracl
#define	DBLU_ZEROFRAC_P(u)	(((u).dblu_frach|(u).dblu_fracl) != 0)

#if __HAVE_LONG_DOUBLE + 0 == 128
union ieee_ext_u {
	long double		extu_ld;
	struct ieee_ext		extu_ext;
};

#define extu_exp	extu_ext.ext_exp
#define extu_sign	extu_ext.ext_sign
#define extu_fracl	extu_ext.ext_fracl
#define extu_frach	extu_ext.ext_frach
#define	EXTU_ZEROFRAC_P(u)	(((u).extu_frach|(u).extu_fracl) != 0)

#ifndef LDBL_NBIT
#define LDBL_IMPLICIT_NBIT	1	/* our NBIT is implicit */
#endif

#endif /* __HAVE_LONG_DOUBLE */

#endif /* _SYS_IEEE754_H_ */