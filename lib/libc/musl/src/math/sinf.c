/* origin: FreeBSD /usr/src/lib/msun/src/s_sinf.c */
/*
 * Conversion to float by Ian Lance Taylor, Cygnus Support, ian@cygnus.com.
 * Optimized by Bruce D. Evans.
 */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */

#include "libm.h"

/* Small multiples of pi/2 rounded to double precision. */
static const double
s1pio2 = 1*M_PI_2, /* 0x3FF921FB, 0x54442D18 */
s2pio2 = 2*M_PI_2, /* 0x400921FB, 0x54442D18 */
s3pio2 = 3*M_PI_2, /* 0x4012D97C, 0x7F3321D2 */
s4pio2 = 4*M_PI_2; /* 0x401921FB, 0x54442D18 */

float sinf(float x)
{
	double y;
	uint32_t ix;
	int n, sign;

	GET_FLOAT_WORD(ix, x);
	sign = ix >> 31;
	ix &= 0x7fffffff;

	if (ix <= 0x3f490fda) {  /* |x| ~<= pi/4 */
		if (ix < 0x39800000) {  /* |x| < 2**-12 */
			/* raise inexact if x!=0 and underflow if subnormal */
			FORCE_EVAL(ix < 0x00800000 ? x/0x1p120f : x+0x1p120f);
			return x;
		}
		return __sindf(x);
	}
	if (ix <= 0x407b53d1) {  /* |x| ~<= 5*pi/4 */
		if (ix <= 0x4016cbe3) {  /* |x| ~<= 3pi/4 */
			if (sign)
				return -__cosdf(x + s1pio2);
			else
				return __cosdf(x - s1pio2);
		}
		return __sindf(sign ? -(x + s2pio2) : -(x - s2pio2));
	}
	if (ix <= 0x40e231d5) {  /* |x| ~<= 9*pi/4 */
		if (ix <= 0x40afeddf) {  /* |x| ~<= 7*pi/4 */
			if (sign)
				return __cosdf(x + s3pio2);
			else
				return -__cosdf(x - s3pio2);
		}
		return __sindf(sign ? x + s4pio2 : x - s4pio2);
	}

	/* sin(Inf or NaN) is NaN */
	if (ix >= 0x7f800000)
		return x - x;

	/* general argument reduction needed */
	n = __rem_pio2f(x, &y);
	switch (n&3) {
	case 0: return  __sindf(y);
	case 1: return  __cosdf(y);
	case 2: return  __sindf(-y);
	default:
		return -__cosdf(y);
	}
}
