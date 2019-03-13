/* origin: FreeBSD /usr/src/lib/msun/src/s_log1pf.c */
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

static const float
ln2_hi = 6.9313812256e-01, /* 0x3f317180 */
ln2_lo = 9.0580006145e-06, /* 0x3717f7d1 */
/* |(log(1+s)-log(1-s))/s - Lg(s)| < 2**-34.24 (~[-4.95e-11, 4.97e-11]). */
Lg1 = 0xaaaaaa.0p-24, /* 0.66666662693 */
Lg2 = 0xccce13.0p-25, /* 0.40000972152 */
Lg3 = 0x91e9ee.0p-25, /* 0.28498786688 */
Lg4 = 0xf89e26.0p-26; /* 0.24279078841 */

float log1pf(float x)
{
	union {float f; uint32_t i;} u = {x};
	float_t hfsq,f,c,s,z,R,w,t1,t2,dk;
	uint32_t ix,iu;
	int k;

	ix = u.i;
	k = 1;
	if (ix < 0x3ed413d0 || ix>>31) {  /* 1+x < sqrt(2)+  */
		if (ix >= 0xbf800000) {  /* x <= -1.0 */
			if (x == -1)
				return x/0.0f; /* log1p(-1)=+inf */
			return (x-x)/0.0f;     /* log1p(x<-1)=NaN */
		}
		if (ix<<1 < 0x33800000<<1) {   /* |x| < 2**-24 */
			/* underflow if subnormal */
			if ((ix&0x7f800000) == 0)
				FORCE_EVAL(x*x);
			return x;
		}
		if (ix <= 0xbe95f619) { /* sqrt(2)/2- <= 1+x < sqrt(2)+ */
			k = 0;
			c = 0;
			f = x;
		}
	} else if (ix >= 0x7f800000)
		return x;
	if (k) {
		u.f = 1 + x;
		iu = u.i;
		iu += 0x3f800000 - 0x3f3504f3;
		k = (int)(iu>>23) - 0x7f;
		/* correction term ~ log(1+x)-log(u), avoid underflow in c/u */
		if (k < 25) {
			c = k >= 2 ? 1-(u.f-x) : x-(u.f-1);
			c /= u.f;
		} else
			c = 0;
		/* reduce u into [sqrt(2)/2, sqrt(2)] */
		iu = (iu&0x007fffff) + 0x3f3504f3;
		u.i = iu;
		f = u.f - 1;
	}
	s = f/(2.0f + f);
	z = s*s;
	w = z*z;
	t1= w*(Lg2+w*Lg4);
	t2= z*(Lg1+w*Lg3);
	R = t2 + t1;
	hfsq = 0.5f*f*f;
	dk = k;
	return s*(hfsq+R) + (dk*ln2_lo+c) - hfsq + f + dk*ln2_hi;
}
