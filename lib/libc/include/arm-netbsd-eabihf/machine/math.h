/*	$NetBSD: math.h,v 1.4 2014/01/31 19:38:06 matt Exp $	*/

#define	__HAVE_NANF
#ifdef __ARM_PCS_AAPCS64
#define __HAVE_LONG_DOUBLE	128
#endif