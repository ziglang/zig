/* origin: FreeBSD /usr/src/lib/msun/src/e_asinl.c */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunSoft, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */
/*
 * See comments in asin.c.
 * Converted to long double by David Schultz <das@FreeBSD.ORG>.
 */

#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double asinl(long double x)
{
	return asin(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
#include "__invtrigl.h"
#if LDBL_MANT_DIG == 64
#define CLOSETO1(u) (u.i.m>>56 >= 0xf7)
#define CLEARBOTTOM(u) (u.i.m &= -1ULL << 32)
#elif LDBL_MANT_DIG == 113
#define CLOSETO1(u) (u.i.top >= 0xee00)
#define CLEARBOTTOM(u) (u.i.lo = 0)
#endif

long double asinl(long double x)
{
	union ldshape u = {x};
	long double z, r, s;
	uint16_t e = u.i.se & 0x7fff;
	int sign = u.i.se >> 15;

	if (e >= 0x3fff) {   /* |x| >= 1 or nan */
		/* asin(+-1)=+-pi/2 with inexact */
		if (x == 1 || x == -1)
			return x*pio2_hi + 0x1p-120f;
		return 0/(x-x);
	}
	if (e < 0x3fff - 1) {  /* |x| < 0.5 */
		if (e < 0x3fff - (LDBL_MANT_DIG+1)/2) {
			/* return x with inexact if x!=0 */
			FORCE_EVAL(x + 0x1p120f);
			return x;
		}
		return x + x*__invtrigl_R(x*x);
	}
	/* 1 > |x| >= 0.5 */
	z = (1.0 - fabsl(x))*0.5;
	s = sqrtl(z);
	r = __invtrigl_R(z);
	if (CLOSETO1(u)) {
		x = pio2_hi - (2*(s+s*r)-pio2_lo);
	} else {
		long double f, c;
		u.f = s;
		CLEARBOTTOM(u);
		f = u.f;
		c = (z - f*f)/(s + f);
		x = 0.5*pio2_hi-(2*s*r - (pio2_lo-2*c) - (0.5*pio2_hi-2*f));
	}
	return sign ? -x : x;
}
#endif
