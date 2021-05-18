/* origin: FreeBSD /usr/src/lib/msun/src/s_cbrtf.c */
/*
 * Conversion to float by Ian Lance Taylor, Cygnus Support, ian@cygnus.com.
 * Debugged and optimized by Bruce D. Evans.
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
/* cbrtf(x)
 * Return cube root of x
 */

#include <math.h>
#include <stdint.h>

static const unsigned
B1 = 709958130, /* B1 = (127-127.0/3-0.03306235651)*2**23 */
B2 = 642849266; /* B2 = (127-127.0/3-24/3-0.03306235651)*2**23 */

float cbrtf(float x)
{
	double_t r,T;
	union {float f; uint32_t i;} u = {x};
	uint32_t hx = u.i & 0x7fffffff;

	if (hx >= 0x7f800000)  /* cbrt(NaN,INF) is itself */
		return x + x;

	/* rough cbrt to 5 bits */
	if (hx < 0x00800000) {  /* zero or subnormal? */
		if (hx == 0)
			return x;  /* cbrt(+-0) is itself */
		u.f = x*0x1p24f;
		hx = u.i & 0x7fffffff;
		hx = hx/3 + B2;
	} else
		hx = hx/3 + B1;
	u.i &= 0x80000000;
	u.i |= hx;

	/*
	 * First step Newton iteration (solving t*t-x/t == 0) to 16 bits.  In
	 * double precision so that its terms can be arranged for efficiency
	 * without causing overflow or underflow.
	 */
	T = u.f;
	r = T*T*T;
	T = T*((double_t)x+x+r)/(x+r+r);

	/*
	 * Second step Newton iteration to 47 bits.  In double precision for
	 * efficiency and accuracy.
	 */
	r = T*T*T;
	T = T*((double_t)x+x+r)/(x+r+r);

	/* rounding to 24 bits is perfect in round-to-nearest mode */
	return T;
}
