/*	$NetBSD: ieeefp.h,v 1.10 2017/01/14 16:07:53 christos Exp $	*/

/*
 * Written by J.T. Conklin, Apr 6, 1995
 * Public domain.
 */

#ifndef _SPARC_IEEEFP_H_
#define _SPARC_IEEEFP_H_

#include <sys/featuretest.h>
#include <machine/fenv.h>

#if defined(_NETBSD_SOURCE) && !defined(_ISOC99_SOURCE)

typedef unsigned int fp_except;
#define FP_X_IMP	0x01		/* imprecise (loss of precision) */
#define FP_X_DZ		0x02		/* divide-by-zero exception */
#define FP_X_UFL	0x04		/* underflow exception */
#define FP_X_OFL	0x08		/* overflow exception */
#define FP_X_INV	0x10		/* invalid operation exception */

typedef enum {
    FP_RN=0,			/* round to nearest representable number */
    FP_RZ=1,			/* round to zero (truncate) */
    FP_RP=2,			/* round toward positive infinity */
    FP_RM=3			/* round toward negative infinity */
} fp_rnd;

#endif /* _NETBSD_SOURCE || !_ISOC99_SOURCE */

#endif /* _SPARC_IEEEFP_H_ */