/* origin: FreeBSD /usr/src/lib/msun/src/e_scalb.c */
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
 * scalb(x, fn) is provide for
 * passing various standard test suite. One
 * should use scalbn() instead.
 */

#define _GNU_SOURCE
#include <math.h>

double scalb(double x, double fn)
{
	if (isnan(x) || isnan(fn))
		return x*fn;
	if (!isfinite(fn)) {
		if (fn > 0.0)
			return x*fn;
		else
			return x/(-fn);
	}
	if (rint(fn) != fn) return (fn-fn)/(fn-fn);
	if ( fn > 65000.0) return scalbn(x, 65000);
	if (-fn > 65000.0) return scalbn(x,-65000);
	return scalbn(x,(int)fn);
}
