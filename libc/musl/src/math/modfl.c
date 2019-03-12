#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double modfl(long double x, long double *iptr)
{
	double d;
	long double r;

	r = modf(x, &d);
	*iptr = d;
	return r;
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384

static const long double toint = 1/LDBL_EPSILON;

long double modfl(long double x, long double *iptr)
{
	union ldshape u = {x};
	int e = (u.i.se & 0x7fff) - 0x3fff;
	int s = u.i.se >> 15;
	long double absx;
	long double y;

	/* no fractional part */
	if (e >= LDBL_MANT_DIG-1) {
		*iptr = x;
		if (isnan(x))
			return x;
		return s ? -0.0 : 0.0;
	}

	/* no integral part*/
	if (e < 0) {
		*iptr = s ? -0.0 : 0.0;
		return x;
	}

	/* raises spurious inexact */
	absx = s ? -x : x;
	y = absx + toint - toint - absx;
	if (y == 0) {
		*iptr = x;
		return s ? -0.0 : 0.0;
	}
	if (y > 0)
		y -= 1;
	if (s)
		y = -y;
	*iptr = x + y;
	return -y;
}
#endif
