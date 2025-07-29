/*	$NetBSD: ieeefp.h,v 1.10 2017/03/22 23:11:09 chs Exp $	*/

/* 
 * Written by J.T. Conklin, Apr 6, 1995
 * Modified by Jason R. Thorpe, June 22, 2003
 * Public domain.
 */

#ifndef _M68K_IEEEFP_H_
#define _M68K_IEEEFP_H_

#include <sys/featuretest.h>

#if defined(_NETBSD_SOURCE) || defined(_ISOC99_SOURCE)

#include <m68k/fenv.h>

#if !defined(_ISOC99_SOURCE)

typedef int fp_except;

/* adjust for FP_* and FE_* value differences */ 
#define	__FPE(x) ((x) >> 3)
#define	__FEE(x) ((x) << 3)
#define	__FPR(x) ((x) >> 4)
#define	__FER(x) ((x) << 4)

#define FP_X_IMP	__FPE(FE_INEXACT)	/* imprecise (loss of precision) */
#define FP_X_DZ		__FPE(FE_DIVBYZERO)	/* divide-by-zero exception */
#define FP_X_UFL	__FPE(FE_UNDERFLOW)	/* underflow exception */
#define FP_X_OFL	__FPE(FE_OVERFLOW)	/* overflow exception */
#define FP_X_INV	__FPE(FE_INVALID)	/* invalid operation exception */

typedef enum {
    FP_RN=__FPR(FE_TONEAREST),	/* round to nearest representable number */
    FP_RZ=__FPR(FE_TOWARDZERO),	/* round to zero (truncate) */
    FP_RM=__FPR(FE_DOWNWARD),	/* round toward negative infinity */
    FP_RP=__FPR(FE_UPWARD)	/* round toward positive infinity */
} fp_rnd;

typedef enum {
    FP_PE=0,			/* extended-precision (64-bit) */
    FP_PS=1,			/* single-precision (24-bit) */
    FP_PD=2			/* double-precision (53-bit) */
} fp_prec;

#endif /* !_ISOC99_SOURCE */

#define	__HAVE_FP_PREC

#endif	/* _NETBSD_SOURCE || _ISOC99_SOURCE */

#endif /* _M68K_IEEEFP_H_ */