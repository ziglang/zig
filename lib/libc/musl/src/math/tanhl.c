#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double tanhl(long double x)
{
	return tanh(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
long double tanhl(long double x)
{
	union ldshape u = {x};
	unsigned ex = u.i.se & 0x7fff;
	unsigned sign = u.i.se & 0x8000;
	uint32_t w;
	long double t;

	/* x = |x| */
	u.i.se = ex;
	x = u.f;
	w = u.i.m >> 32;

	if (ex > 0x3ffe || (ex == 0x3ffe && w > 0x8c9f53d5)) {
		/* |x| > log(3)/2 ~= 0.5493 or nan */
		if (ex >= 0x3fff+5) {
			/* |x| >= 32 */
			t = 1 + 0/(x + 0x1p-120f);
		} else {
			t = expm1l(2*x);
			t = 1 - 2/(t+2);
		}
	} else if (ex > 0x3ffd || (ex == 0x3ffd && w > 0x82c577d4)) {
		/* |x| > log(5/3)/2 ~= 0.2554 */
		t = expm1l(2*x);
		t = t/(t+2);
	} else {
		/* |x| is small */
		t = expm1l(-2*x);
		t = -t/(t+2);
	}
	return sign ? -t : t;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
// TODO: broken implementation to make things compile
long double tanhl(long double x)
{
	return tanh(x);
}
#endif
