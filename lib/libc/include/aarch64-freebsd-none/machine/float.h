/*-
 * Copyright (c) 1989 Regents of the University of California.
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
 *	from: @(#)float.h	7.1 (Berkeley) 5/8/90
 */

#ifdef __arm__
#include <arm/float.h>
#else /* !__arm__ */

#ifndef _MACHINE_FLOAT_H_
#define	_MACHINE_FLOAT_H_

#include <sys/cdefs.h>

__BEGIN_DECLS
extern int __flt_rounds(void);
__END_DECLS

#define	FLT_RADIX	2		/* b */
#define	FLT_ROUNDS	__flt_rounds()
#if __ISO_C_VISIBLE >= 1999
#define	FLT_EVAL_METHOD	0
#define	DECIMAL_DIG	17		/* max precision in decimal digits */
#endif

#define	FLT_MANT_DIG	24		/* p */
#define	FLT_EPSILON	1.19209290E-07F	/* b**(1-p) */
#define	FLT_DIG		6		/* floor((p-1)*log10(b))+(b == 10) */
#define	FLT_MIN_EXP	(-125)		/* emin */
#define	FLT_MIN		1.17549435E-38F	/* b**(emin-1) */
#define	FLT_MIN_10_EXP	(-37)		/* ceil(log10(b**(emin-1))) */
#define	FLT_MAX_EXP	128		/* emax */
#define	FLT_MAX		3.40282347E+38F	/* (1-b**(-p))*b**emax */
#define	FLT_MAX_10_EXP	38		/* floor(log10((1-b**(-p))*b**emax)) */
#if __ISO_C_VISIBLE >= 2011
#define	FLT_TRUE_MIN	1.40129846E-45F	/* b**(emin-p) */
#define	FLT_DECIMAL_DIG	9		/* ceil(1+p*log10(b)) */
#define	FLT_HAS_SUBNORM	1
#endif /* __ISO_C_VISIBLE >= 2011 */

#define	DBL_MANT_DIG	53
#define	DBL_EPSILON	2.2204460492503131E-16
#define	DBL_DIG		15
#define	DBL_MIN_EXP	(-1021)
#define	DBL_MIN		2.2250738585072014E-308
#define	DBL_MIN_10_EXP	(-307)
#define	DBL_MAX_EXP	1024
#define	DBL_MAX		1.7976931348623157E+308
#define	DBL_MAX_10_EXP	308
#if __ISO_C_VISIBLE >= 2011
#define	DBL_TRUE_MIN	4.9406564584124654E-324
#define	DBL_DECIMAL_DIG	17
#define	DBL_HAS_SUBNORM	1
#endif /* __ISO_C_VISIBLE >= 2011 */

#define	LDBL_MANT_DIG	113
#define	LDBL_EPSILON	1.925929944387235853055977942584927319E-34L
#define	LDBL_DIG	33
#define	LDBL_MIN_EXP	(-16381)
#define	LDBL_MIN	3.362103143112093506262677817321752603E-4932L
#define	LDBL_MIN_10_EXP	(-4931)
#define	LDBL_MAX_EXP	(+16384)
#define	LDBL_MAX	1.189731495357231765085759326628007016E+4932L
#define	LDBL_MAX_10_EXP	(+4932)
#if __ISO_C_VISIBLE >= 2011
#define	LDBL_TRUE_MIN	6.475175119438025110924438958227646552E-4966L
#define	LDBL_DECIMAL_DIG 36
#define	LDBL_HAS_SUBNORM 1
#endif /* __ISO_C_VISIBLE >= 2011 */

#endif /* _MACHINE_FLOAT_H_ */

#endif /* !__arm__ */