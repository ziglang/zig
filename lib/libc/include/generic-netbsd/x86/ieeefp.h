/*	$NetBSD: ieeefp.h,v 1.4 2011/03/26 19:52:20 christos Exp $	*/

/* 
 * Written by J.T. Conklin, Apr 6, 1995
 * Public domain.
 */

#ifndef _X86_IEEEFP_H_
#define _X86_IEEEFP_H_

#include <sys/featuretest.h>
#include <machine/fenv.h>

typedef int fp_except;
#define FP_X_INV	FE_INVALID	/* invalid operation exception */
#define FP_X_DNML	FE_DENORMAL	/* denormalization exception */
#define FP_X_DZ		FE_DIVBYZERO	/* divide-by-zero exception */
#define FP_X_OFL	FE_OVERFLOW	/* overflow exception */
#define FP_X_UFL	FE_UNDERFLOW	/* underflow exception */
#define FP_X_IMP	FE_INEXACT	/* imprecise (loss of precision) */

typedef enum {
	FP_RN=FE_TONEAREST,		/* round to nearest representable num */
	FP_RM=FE_DOWNWARD,		/* round toward negative infinity */
	FP_RP=FE_UPWARD,		/* round toward positive infinity */
	FP_RZ=FE_TOWARDZERO		/* round to zero (truncate) */
} fp_rnd;

typedef enum {
	FP_PS = 0,			/* 24 bit (single-precision) */
	FP_PRS,				/* reserved */
	FP_PD,				/* 53 bit (double-precision) */
	FP_PE				/* 64 bit (extended-precision) */
} fp_prec;


#endif /* _X86_IEEEFP_H_ */