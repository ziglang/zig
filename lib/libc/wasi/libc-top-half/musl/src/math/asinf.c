/* origin: FreeBSD /usr/src/lib/msun/src/e_asinf.c */
/*
 * Conversion to float by Ian Lance Taylor, Cygnus Support, ian@cygnus.com.
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

static const double
pio2 = 1.570796326794896558e+00;

static const float
/* coefficients for R(x^2) */
pS0 =  1.6666586697e-01,
pS1 = -4.2743422091e-02,
pS2 = -8.6563630030e-03,
qS1 = -7.0662963390e-01;

static float R(float z)
{
	float_t p, q;
	p = z*(pS0+z*(pS1+z*pS2));
	q = 1.0f+z*qS1;
	return p/q;
}

float asinf(float x)
{
	double s;
	float z;
	uint32_t hx,ix;

	GET_FLOAT_WORD(hx, x);
	ix = hx & 0x7fffffff;
	if (ix >= 0x3f800000) {  /* |x| >= 1 */
		if (ix == 0x3f800000)  /* |x| == 1 */
			return x*pio2 + 0x1p-120f;  /* asin(+-1) = +-pi/2 with inexact */
		return 0/(x-x);  /* asin(|x|>1) is NaN */
	}
	if (ix < 0x3f000000) {  /* |x| < 0.5 */
		/* if 0x1p-126 <= |x| < 0x1p-12, avoid raising underflow */
		if (ix < 0x39800000 && ix >= 0x00800000)
			return x;
		return x + x*R(x*x);
	}
	/* 1 > |x| >= 0.5 */
	z = (1 - fabsf(x))*0.5f;
	s = sqrt(z);
	x = pio2 - 2*(s+s*R(z));
	if (hx >> 31)
		return -x;
	return x;
}
