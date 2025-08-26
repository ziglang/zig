/* origin: FreeBSD /usr/src/lib/msun/src/e_acos.c */
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
/* acos(x)
 * Method :
 *      acos(x)  = pi/2 - asin(x)
 *      acos(-x) = pi/2 + asin(x)
 * For |x|<=0.5
 *      acos(x) = pi/2 - (x + x*x^2*R(x^2))     (see asin.c)
 * For x>0.5
 *      acos(x) = pi/2 - (pi/2 - 2asin(sqrt((1-x)/2)))
 *              = 2asin(sqrt((1-x)/2))
 *              = 2s + 2s*z*R(z)        ...z=(1-x)/2, s=sqrt(z)
 *              = 2f + (2c + 2s*z*R(z))
 *     where f=hi part of s, and c = (z-f*f)/(s+f) is the correction term
 *     for f so that f+c ~ sqrt(z).
 * For x<-0.5
 *      acos(x) = pi - 2asin(sqrt((1-|x|)/2))
 *              = pi - 0.5*(s+s*z*R(z)), where z=(1-|x|)/2,s=sqrt(z)
 *
 * Special cases:
 *      if x is NaN, return x itself;
 *      if |x|>1, return NaN with invalid signal.
 *
 * Function needed: sqrt
 */

#include "libm.h"

static const double
pio2_hi = 1.57079632679489655800e+00, /* 0x3FF921FB, 0x54442D18 */
pio2_lo = 6.12323399573676603587e-17, /* 0x3C91A626, 0x33145C07 */
pS0 =  1.66666666666666657415e-01, /* 0x3FC55555, 0x55555555 */
pS1 = -3.25565818622400915405e-01, /* 0xBFD4D612, 0x03EB6F7D */
pS2 =  2.01212532134862925881e-01, /* 0x3FC9C155, 0x0E884455 */
pS3 = -4.00555345006794114027e-02, /* 0xBFA48228, 0xB5688F3B */
pS4 =  7.91534994289814532176e-04, /* 0x3F49EFE0, 0x7501B288 */
pS5 =  3.47933107596021167570e-05, /* 0x3F023DE1, 0x0DFDF709 */
qS1 = -2.40339491173441421878e+00, /* 0xC0033A27, 0x1C8A2D4B */
qS2 =  2.02094576023350569471e+00, /* 0x40002AE5, 0x9C598AC8 */
qS3 = -6.88283971605453293030e-01, /* 0xBFE6066C, 0x1B8D0159 */
qS4 =  7.70381505559019352791e-02; /* 0x3FB3B8C5, 0xB12E9282 */

static double R(double z)
{
	double_t p, q;
	p = z*(pS0+z*(pS1+z*(pS2+z*(pS3+z*(pS4+z*pS5)))));
	q = 1.0+z*(qS1+z*(qS2+z*(qS3+z*qS4)));
	return p/q;
}

double acos(double x)
{
	double z,w,s,c,df;
	uint32_t hx,ix;

	GET_HIGH_WORD(hx, x);
	ix = hx & 0x7fffffff;
	/* |x| >= 1 or nan */
	if (ix >= 0x3ff00000) {
		uint32_t lx;

		GET_LOW_WORD(lx,x);
		if ((ix-0x3ff00000 | lx) == 0) {
			/* acos(1)=0, acos(-1)=pi */
			if (hx >> 31)
				return 2*pio2_hi + 0x1p-120f;
			return 0;
		}
		return 0/(x-x);
	}
	/* |x| < 0.5 */
	if (ix < 0x3fe00000) {
		if (ix <= 0x3c600000)  /* |x| < 2**-57 */
			return pio2_hi + 0x1p-120f;
		return pio2_hi - (x - (pio2_lo-x*R(x*x)));
	}
	/* x < -0.5 */
	if (hx >> 31) {
		z = (1.0+x)*0.5;
		s = sqrt(z);
		w = R(z)*s-pio2_lo;
		return 2*(pio2_hi - (s+w));
	}
	/* x > 0.5 */
	z = (1.0-x)*0.5;
	s = sqrt(z);
	df = s;
	SET_LOW_WORD(df,0);
	c = (z-df*df)/(s+df);
	w = R(z)*s+c;
	return 2*(df+w);
}
