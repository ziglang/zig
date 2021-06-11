#include "libm.h"

#if FLT_EVAL_METHOD==2
#undef sqrt
#define sqrt sqrtl
#endif

/* acosh(x) = log(x + sqrt(x*x-1)) */
double acosh(double x)
{
	union {double f; uint64_t i;} u = {.f = x};
	unsigned e = u.i >> 52 & 0x7ff;

	/* x < 1 domain error is handled in the called functions */

	if (e < 0x3ff + 1)
		/* |x| < 2, up to 2ulp error in [1,1.125] */
		return log1p(x-1 + sqrt((x-1)*(x-1)+2*(x-1)));
	if (e < 0x3ff + 26)
		/* |x| < 0x1p26 */
		return log(2*x - 1/(x+sqrt(x*x-1)));
	/* |x| >= 0x1p26 or nan */
	return log(x) + 0.693147180559945309417232121458176568;
}
