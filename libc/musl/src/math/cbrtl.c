/* origin: FreeBSD /usr/src/lib/msun/src/s_cbrtl.c */
/*-
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 * Copyright (c) 2009-2011, Bruce D. Evans, Steven G. Kargl, David Schultz.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 *
 * The argument reduction and testing for exceptional cases was
 * written by Steven G. Kargl with input from Bruce D. Evans
 * and David A. Schultz.
 */

#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double cbrtl(long double x)
{
	return cbrt(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
static const unsigned B1 = 709958130; /* B1 = (127-127.0/3-0.03306235651)*2**23 */

long double cbrtl(long double x)
{
	union ldshape u = {x}, v;
	union {float f; uint32_t i;} uft;
	long double r, s, t, w;
	double_t dr, dt, dx;
	float_t ft;
	int e = u.i.se & 0x7fff;
	int sign = u.i.se & 0x8000;

	/*
	 * If x = +-Inf, then cbrt(x) = +-Inf.
	 * If x = NaN, then cbrt(x) = NaN.
	 */
	if (e == 0x7fff)
		return x + x;
	if (e == 0) {
		/* Adjust subnormal numbers. */
		u.f *= 0x1p120;
		e = u.i.se & 0x7fff;
		/* If x = +-0, then cbrt(x) = +-0. */
		if (e == 0)
			return x;
		e -= 120;
	}
	e -= 0x3fff;
	u.i.se = 0x3fff;
	x = u.f;
	switch (e % 3) {
	case 1:
	case -2:
		x *= 2;
		e--;
		break;
	case 2:
	case -1:
		x *= 4;
		e -= 2;
		break;
	}
	v.f = 1.0;
	v.i.se = sign | (0x3fff + e/3);

	/*
	 * The following is the guts of s_cbrtf, with the handling of
	 * special values removed and extra care for accuracy not taken,
	 * but with most of the extra accuracy not discarded.
	 */

	/* ~5-bit estimate: */
	uft.f = x;
	uft.i = (uft.i & 0x7fffffff)/3 + B1;
	ft = uft.f;

	/* ~16-bit estimate: */
	dx = x;
	dt = ft;
	dr = dt * dt * dt;
	dt = dt * (dx + dx + dr) / (dx + dr + dr);

	/* ~47-bit estimate: */
	dr = dt * dt * dt;
	dt = dt * (dx + dx + dr) / (dx + dr + dr);

#if LDBL_MANT_DIG == 64
	/*
	 * dt is cbrtl(x) to ~47 bits (after x has been reduced to 1 <= x < 8).
	 * Round it away from zero to 32 bits (32 so that t*t is exact, and
	 * away from zero for technical reasons).
	 */
	t = dt + (0x1.0p32L + 0x1.0p-31L) - 0x1.0p32;
#elif LDBL_MANT_DIG == 113
	/*
	 * Round dt away from zero to 47 bits.  Since we don't trust the 47,
	 * add 2 47-bit ulps instead of 1 to round up.  Rounding is slow and
	 * might be avoidable in this case, since on most machines dt will
	 * have been evaluated in 53-bit precision and the technical reasons
	 * for rounding up might not apply to either case in cbrtl() since
	 * dt is much more accurate than needed.
	 */
	t = dt + 0x2.0p-46 + 0x1.0p60L - 0x1.0p60;
#endif

	/*
	 * Final step Newton iteration to 64 or 113 bits with
	 * error < 0.667 ulps
	 */
	s = t*t;         /* t*t is exact */
	r = x/s;         /* error <= 0.5 ulps; |r| < |t| */
	w = t+t;         /* t+t is exact */
	r = (r-t)/(w+r); /* r-t is exact; w+r ~= 3*t */
	t = t+t*r;       /* error <= 0.5 + 0.5/3 + epsilon */

	t *= v.f;
	return t;
}
#endif
