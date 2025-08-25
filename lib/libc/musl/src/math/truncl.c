#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double truncl(long double x)
{
	return trunc(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384

static const long double toint = 1/LDBL_EPSILON;

long double truncl(long double x)
{
	union ldshape u = {x};
	int e = u.i.se & 0x7fff;
	int s = u.i.se >> 15;
	long double y;

	if (e >= 0x3fff+LDBL_MANT_DIG-1)
		return x;
	if (e <= 0x3fff-1) {
		FORCE_EVAL(x + 0x1p120f);
		return x*0;
	}
	/* y = int(|x|) - |x|, where int(|x|) is an integer neighbor of |x| */
	if (s)
		x = -x;
	y = x + toint - toint - x;
	if (y > 0)
		y -= 1;
	x += y;
	return s ? -x : x;
}
#endif
