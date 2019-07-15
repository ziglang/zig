#include "libm.h"

/* asinh(x) = sign(x)*log(|x|+sqrt(x*x+1)) ~= x - x^3/6 + o(x^5) */
float asinhf(float x)
{
	union {float f; uint32_t i;} u = {.f = x};
	uint32_t i = u.i & 0x7fffffff;
	unsigned s = u.i >> 31;

	/* |x| */
	u.i = i;
	x = u.f;

	if (i >= 0x3f800000 + (12<<23)) {
		/* |x| >= 0x1p12 or inf or nan */
		x = logf(x) + 0.693147180559945309417232121458176568f;
	} else if (i >= 0x3f800000 + (1<<23)) {
		/* |x| >= 2 */
		x = logf(2*x + 1/(sqrtf(x*x+1)+x));
	} else if (i >= 0x3f800000 - (12<<23)) {
		/* |x| >= 0x1p-12, up to 1.6ulp error in [0.125,0.5] */
		x = log1pf(x + x*x/(sqrtf(x*x+1)+1));
	} else {
		/* |x| < 0x1p-12, raise inexact if x!=0 */
		FORCE_EVAL(x + 0x1p120f);
	}
	return s ? -x : x;
}
