/*	$NetBSD: ieee.h,v 1.6 2014/10/22 10:32:50 joerg Exp $	*/

#include <sys/ieee754.h>

/*
 * A NaN is a `signalling NaN' if its QUIETNAN bit is clear in its
 * high fraction; if the bit is set, it is a `quiet NaN'.
 */

#if 0
#define	SNG_QUIETNAN	(1 << 22)
#define	DBL_QUIETNAN	(1 << 19)
#endif

union ldbl_u {
	long double	ldblu_ld;
	double		ldblu_d[2];
};