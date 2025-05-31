/*	$NetBSD: ieeefp.h,v 1.11 2020/07/26 08:08:41 simonb Exp $	*/

/*
 * Written by J.T. Conklin, Apr 11, 1995
 * Public domain.
 */

#ifndef _MIPS_IEEEFP_H_
#define	_MIPS_IEEEFP_H_

#include <sys/featuretest.h>

#if defined(_NETBSD_SOURCE) || defined(_ISOC99_SOURCE)

#include <mips/fenv.h>

#if !defined(_ISOC99_SOURCE)

typedef unsigned int fp_except;

/* adjust for FP_* and FE_* value differences */
#define	__FPE(x) ((x) >> 2)
#define	__FEE(x) ((x) << 2)
#define	__FPR(x) ((x))
#define	__FER(x) ((x))

#define	FP_X_IMP	__FPE(FE_INEXACT)	/* imprecise (loss of precision) */
#define	FP_X_UFL	__FPE(FE_UNDERFLOW)	/* underflow exception */
#define	FP_X_OFL	__FPE(FE_OVERFLOW)	/* overflow exception */
#define	FP_X_DZ		__FPE(FE_DIVBYZERO)	/* divide-by-zero exception */
#define	FP_X_INV	__FPE(FE_INVALID)	/* invalid operation exception */

typedef enum {
    FP_RN=FE_TONEAREST,		/* round to nearest representable number */
    FP_RZ=FE_TOWARDZERO,	/* round to zero (truncate) */
    FP_RP=FE_UPWARD,		/* round toward positive infinity */
    FP_RM=FE_DOWNWARD		/* round toward negative infinity */
} fp_rnd;

#endif /* !_ISOC99_SOURCE */

#endif /* _NETBSD_SOURCE || _ISOC99_SOURCE */

#endif /* _MIPS_IEEEFP_H_ */