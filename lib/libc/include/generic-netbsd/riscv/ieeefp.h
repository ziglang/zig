/*	$NetBSD: ieeefp.h,v 1.2 2020/03/14 16:12:16 skrll Exp $	*/

/*
 * Based on ieeefp.h written by J.T. Conklin, Apr 28, 1995
 * Public domain.
 */

#ifndef _RISCV_IEEEFP_H_
#define _RISCV_IEEEFP_H_

#include <sys/featuretest.h>

#if defined(_NETBSD_SOURCE) || defined(_ISOC99_SOURCE)

#include <riscv/fenv.h>

#if !defined(_ISOC99_SOURCE)

/* Exception type (used by fpsetmask() et al.) */

typedef int fp_except;

/* Bit defines for fp_except */

#define	FP_X_INV	FE_INVALID	/* invalid operation exception */
#define	FP_X_DZ		FE_DIVBYZERO	/* divide-by-zero exception */
#define	FP_X_OFL	FE_OVERFLOW	/* overflow exception */
#define	FP_X_UFL	FE_UNDERFLOW	/* underflow exception */
#define	FP_X_IMP	FE_INEXACT	/* imprecise (prec. loss; "inexact") */

/* Rounding modes */

typedef enum {
    FP_RN=FE_TONEAREST,		/* round to nearest representable number */
    FP_RP=FE_UPWARD,		/* round toward positive infinity */
    FP_RM=FE_DOWNWARD,		/* round toward negative infinity */
    FP_RZ=FE_TOWARDZERO		/* round to zero (truncate) */
} fp_rnd;

#endif /* !_ISOC99_SOURCE */

#endif /* _NETBSD_SOURCE || _ISOC99_SOURCE */

#endif /* _RISCV_IEEEFP_H_ */