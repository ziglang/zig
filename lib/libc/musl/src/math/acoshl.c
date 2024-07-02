#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double acoshl(long double x)
{
	return acosh(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
/* acosh(x) = log(x + sqrt(x*x-1)) */
long double acoshl(long double x)
{
	union ldshape u = {x};
	int e = u.i.se;

	if (e < 0x3fff + 1)
		/* 0 <= x < 2, invalid if x < 1 */
		return log1pl(x-1 + sqrtl((x-1)*(x-1)+2*(x-1)));
	if (e < 0x3fff + 32)
		/* 2 <= x < 0x1p32 */
		return logl(2*x - 1/(x+sqrtl(x*x-1)));
	if (e & 0x8000)
		/* x < 0 or x = -0, invalid */
		return (x - x) / (x - x);
	/* 0x1p32 <= x or nan */
	return logl(x) + 0.693147180559945309417232121458176568L;
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
// TODO: broken implementation to make things compile
long double acoshl(long double x)
{
	return acosh(x);
}
#endif
