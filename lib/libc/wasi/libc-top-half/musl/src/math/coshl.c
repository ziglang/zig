#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double coshl(long double x)
{
	return cosh(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
long double coshl(long double x)
{
	union ldshape u = {x};
	unsigned ex = u.i.se & 0x7fff;
	uint32_t w;
	long double t;

	/* |x| */
	u.i.se = ex;
	x = u.f;
	w = u.i.m >> 32;

	/* |x| < log(2) */
	if (ex < 0x3fff-1 || (ex == 0x3fff-1 && w < 0xb17217f7)) {
		if (ex < 0x3fff-32) {
			FORCE_EVAL(x + 0x1p120f);
			return 1;
		}
		t = expm1l(x);
		return 1 + t*t/(2*(1+t));
	}

	/* |x| < log(LDBL_MAX) */
	if (ex < 0x3fff+13 || (ex == 0x3fff+13 && w < 0xb17217f7)) {
		t = expl(x);
		return 0.5*(t + 1/t);
	}

	/* |x| > log(LDBL_MAX) or nan */
	t = expl(0.5*x);
	return 0.5*t*t;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
// TODO: broken implementation to make things compile
long double coshl(long double x)
{
	return cosh(x);
}
#endif
