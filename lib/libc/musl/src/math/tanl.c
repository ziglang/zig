#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double tanl(long double x)
{
	return tan(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
long double tanl(long double x)
{
	union ldshape u = {x};
	long double y[2];
	unsigned n;

	u.i.se &= 0x7fff;
	if (u.i.se == 0x7fff)
		return x - x;
	if (u.f < M_PI_4) {
		if (u.i.se < 0x3fff - LDBL_MANT_DIG/2) {
			/* raise inexact if x!=0 and underflow if subnormal */
			FORCE_EVAL(u.i.se == 0 ? x*0x1p-120f : x+0x1p120f);
			return x;
		}
		return __tanl(x, 0, 0);
	}
	n = __rem_pio2l(x, y);
	return __tanl(y[0], y[1], n&1);
}
#endif
