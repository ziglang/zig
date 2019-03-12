#include <limits.h>
#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
int ilogbl(long double x)
{
	return ilogb(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
int ilogbl(long double x)
{
	#pragma STDC FENV_ACCESS ON
	union ldshape u = {x};
	uint64_t m = u.i.m;
	int e = u.i.se & 0x7fff;

	if (!e) {
		if (m == 0) {
			FORCE_EVAL(0/0.0f);
			return FP_ILOGB0;
		}
		/* subnormal x */
		for (e = -0x3fff+1; m>>63 == 0; e--, m<<=1);
		return e;
	}
	if (e == 0x7fff) {
		FORCE_EVAL(0/0.0f);
		return m<<1 ? FP_ILOGBNAN : INT_MAX;
	}
	return e - 0x3fff;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
int ilogbl(long double x)
{
	#pragma STDC FENV_ACCESS ON
	union ldshape u = {x};
	int e = u.i.se & 0x7fff;

	if (!e) {
		if (x == 0) {
			FORCE_EVAL(0/0.0f);
			return FP_ILOGB0;
		}
		/* subnormal x */
		x *= 0x1p120;
		return ilogbl(x) - 120;
	}
	if (e == 0x7fff) {
		FORCE_EVAL(0/0.0f);
		u.i.se = 0;
		return u.f ? FP_ILOGBNAN : INT_MAX;
	}
	return e - 0x3fff;
}
#endif
