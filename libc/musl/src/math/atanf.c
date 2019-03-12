/* origin: FreeBSD /usr/src/lib/msun/src/s_atanf.c */
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

static const float atanhi[] = {
  4.6364760399e-01, /* atan(0.5)hi 0x3eed6338 */
  7.8539812565e-01, /* atan(1.0)hi 0x3f490fda */
  9.8279368877e-01, /* atan(1.5)hi 0x3f7b985e */
  1.5707962513e+00, /* atan(inf)hi 0x3fc90fda */
};

static const float atanlo[] = {
  5.0121582440e-09, /* atan(0.5)lo 0x31ac3769 */
  3.7748947079e-08, /* atan(1.0)lo 0x33222168 */
  3.4473217170e-08, /* atan(1.5)lo 0x33140fb4 */
  7.5497894159e-08, /* atan(inf)lo 0x33a22168 */
};

static const float aT[] = {
  3.3333328366e-01,
 -1.9999158382e-01,
  1.4253635705e-01,
 -1.0648017377e-01,
  6.1687607318e-02,
};

float atanf(float x)
{
	float_t w,s1,s2,z;
	uint32_t ix,sign;
	int id;

	GET_FLOAT_WORD(ix, x);
	sign = ix>>31;
	ix &= 0x7fffffff;
	if (ix >= 0x4c800000) {  /* if |x| >= 2**26 */
		if (isnan(x))
			return x;
		z = atanhi[3] + 0x1p-120f;
		return sign ? -z : z;
	}
	if (ix < 0x3ee00000) {   /* |x| < 0.4375 */
		if (ix < 0x39800000) {  /* |x| < 2**-12 */
			if (ix < 0x00800000)
				/* raise underflow for subnormal x */
				FORCE_EVAL(x*x);
			return x;
		}
		id = -1;
	} else {
		x = fabsf(x);
		if (ix < 0x3f980000) {  /* |x| < 1.1875 */
			if (ix < 0x3f300000) {  /*  7/16 <= |x| < 11/16 */
				id = 0;
				x = (2.0f*x - 1.0f)/(2.0f + x);
			} else {                /* 11/16 <= |x| < 19/16 */
				id = 1;
				x = (x - 1.0f)/(x + 1.0f);
			}
		} else {
			if (ix < 0x401c0000) {  /* |x| < 2.4375 */
				id = 2;
				x = (x - 1.5f)/(1.0f + 1.5f*x);
			} else {                /* 2.4375 <= |x| < 2**26 */
				id = 3;
				x = -1.0f/x;
			}
		}
	}
	/* end of argument reduction */
	z = x*x;
	w = z*z;
	/* break sum from i=0 to 10 aT[i]z**(i+1) into odd and even poly */
	s1 = z*(aT[0]+w*(aT[2]+w*aT[4]));
	s2 = w*(aT[1]+w*aT[3]);
	if (id < 0)
		return x - x*(s1+s2);
	z = atanhi[id] - ((x*(s1+s2) - atanlo[id]) - x);
	return sign ? -z : z;
}
