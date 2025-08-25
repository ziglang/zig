/*	$NetBSD: math.h,v 1.7 2014/02/01 16:10:12 matt Exp $	*/

#define	__HAVE_NANF

#if defined(_LP64) || defined(_KERNEL)
#define	__HAVE_LONG_DOUBLE	128
#endif