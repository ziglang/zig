#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
double nexttoward(double x, long double y)
{
	return nextafter(x, y);
}
#else
double nexttoward(double x, long double y)
{
	union {double f; uint64_t i;} ux = {x};
	int e;

	if (isnan(x) || isnan(y))
		return x + y;
	if (x == y)
		return y;
	if (x == 0) {
		ux.i = 1;
		if (signbit(y))
			ux.i |= 1ULL<<63;
	} else if (x < y) {
		if (signbit(x))
			ux.i--;
		else
			ux.i++;
	} else {
		if (signbit(x))
			ux.i++;
		else
			ux.i--;
	}
	e = ux.i>>52 & 0x7ff;
	/* raise overflow if ux.f is infinite and x is finite */
	if (e == 0x7ff)
		FORCE_EVAL(x+x);
	/* raise underflow if ux.f is subnormal or zero */
	if (e == 0)
		FORCE_EVAL(x*x + ux.f*ux.f);
	return ux.f;
}
#endif
