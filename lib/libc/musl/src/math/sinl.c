#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double sinl(long double x)
{
	return sin(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
long double sinl(long double x)
{
	union ldshape u = {x};
	unsigned n;
	long double y[2], hi, lo;

	u.i.se &= 0x7fff;
	if (u.i.se == 0x7fff)
		return x - x;
	if (u.f < M_PI_4) {
		if (u.i.se < 0x3fff - LDBL_MANT_DIG/2) {
			/* raise inexact if x!=0 and underflow if subnormal */
			FORCE_EVAL(u.i.se == 0 ? x*0x1p-120f : x+0x1p120f);
			return x;
		}
		return __sinl(x, 0.0, 0);
	}
	n = __rem_pio2l(x, y);
	hi = y[0];
	lo = y[1];
	switch (n & 3) {
	case 0:
		return __sinl(hi, lo, 1);
	case 1:
		return __cosl(hi, lo);
	case 2:
		return -__sinl(hi, lo, 1);
	case 3:
	default:
		return -__cosl(hi, lo);
	}
}
#endif
