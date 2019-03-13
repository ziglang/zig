/* origin: FreeBSD /usr/src/lib/msun/src/e_scalbf.c */
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

#define _GNU_SOURCE
#include <math.h>

float scalbf(float x, float fn)
{
	if (isnan(x) || isnan(fn)) return x*fn;
	if (!isfinite(fn)) {
		if (fn > 0.0f)
			return x*fn;
		else
			return x/(-fn);
	}
	if (rintf(fn) != fn) return (fn-fn)/(fn-fn);
	if ( fn > 65000.0f) return scalbnf(x, 65000);
	if (-fn > 65000.0f) return scalbnf(x,-65000);
	return scalbnf(x,(int)fn);
}
