#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double atanhl(long double x)
{
	return atanh(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
/* atanh(x) = log((1+x)/(1-x))/2 = log1p(2x/(1-x))/2 ~= x + x^3/3 + o(x^5) */
long double atanhl(long double x)
{
	union ldshape u = {x};
	unsigned e = u.i.se & 0x7fff;
	unsigned s = u.i.se >> 15;

	/* |x| */
	u.i.se = e;
	x = u.f;

	if (e < 0x3ff - 1) {
		if (e < 0x3ff - LDBL_MANT_DIG/2) {
			/* handle underflow */
			if (e == 0)
				FORCE_EVAL((float)x);
		} else {
			/* |x| < 0.5, up to 1.7ulp error */
			x = 0.5*log1pl(2*x + 2*x*x/(1-x));
		}
	} else {
		/* avoid overflow */
		x = 0.5*log1pl(2*(x/(1-x)));
	}
	return s ? -x : x;
}
#endif
