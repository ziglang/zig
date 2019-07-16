#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double nextafterl(long double x, long double y)
{
	return nextafter(x, y);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
long double nextafterl(long double x, long double y)
{
	union ldshape ux, uy;

	if (isnan(x) || isnan(y))
		return x + y;
	if (x == y)
		return y;
	ux.f = x;
	if (x == 0) {
		uy.f = y;
		ux.i.m = 1;
		ux.i.se = uy.i.se & 0x8000;
	} else if ((x < y) == !(ux.i.se & 0x8000)) {
		ux.i.m++;
		if (ux.i.m << 1 == 0) {
			ux.i.m = 1ULL << 63;
			ux.i.se++;
		}
	} else {
		if (ux.i.m << 1 == 0) {
			ux.i.se--;
			if (ux.i.se)
				ux.i.m = 0;
		}
		ux.i.m--;
	}
	/* raise overflow if ux is infinite and x is finite */
	if ((ux.i.se & 0x7fff) == 0x7fff)
		return x + x;
	/* raise underflow if ux is subnormal or zero */
	if ((ux.i.se & 0x7fff) == 0)
		FORCE_EVAL(x*x + ux.f*ux.f);
	return ux.f;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
long double nextafterl(long double x, long double y)
{
	union ldshape ux, uy;

	if (isnan(x) || isnan(y))
		return x + y;
	if (x == y)
		return y;
	ux.f = x;
	if (x == 0) {
		uy.f = y;
		ux.i.lo = 1;
		ux.i.se = uy.i.se & 0x8000;
	} else if ((x < y) == !(ux.i.se & 0x8000)) {
		ux.i2.lo++;
		if (ux.i2.lo == 0)
			ux.i2.hi++;
	} else {
		if (ux.i2.lo == 0)
			ux.i2.hi--;
		ux.i2.lo--;
	}
	/* raise overflow if ux is infinite and x is finite */
	if ((ux.i.se & 0x7fff) == 0x7fff)
		return x + x;
	/* raise underflow if ux is subnormal or zero */
	if ((ux.i.se & 0x7fff) == 0)
		FORCE_EVAL(x*x + ux.f*ux.f);
	return ux.f;
}
#endif
