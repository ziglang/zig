#define _GNU_SOURCE
#include <float.h>
#include <math.h>
#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double exp10l(long double x)
{
	return exp10(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384
long double exp10l(long double x)
{
	static const long double p10[] = {
		1e-15L, 1e-14L, 1e-13L, 1e-12L, 1e-11L, 1e-10L,
		1e-9L, 1e-8L, 1e-7L, 1e-6L, 1e-5L, 1e-4L, 1e-3L, 1e-2L, 1e-1L,
		1, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
		1e10, 1e11, 1e12, 1e13, 1e14, 1e15
	};
	long double n, y = modfl(x, &n);
	union ldshape u = {n};
	/* fabsl(n) < 16 without raising invalid on nan */
	if ((u.i.se & 0x7fff) < 0x3fff+4) {
		if (!y) return p10[(int)n+15];
		y = exp2l(3.32192809488736234787031942948939L * y);
		return y * p10[(int)n+15];
	}
	return powl(10.0, x);
}
#endif

weak_alias(exp10l, pow10l);
