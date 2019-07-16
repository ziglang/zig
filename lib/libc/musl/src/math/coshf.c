#include "libm.h"

float coshf(float x)
{
	union {float f; uint32_t i;} u = {.f = x};
	uint32_t w;
	float t;

	/* |x| */
	u.i &= 0x7fffffff;
	x = u.f;
	w = u.i;

	/* |x| < log(2) */
	if (w < 0x3f317217) {
		if (w < 0x3f800000 - (12<<23)) {
			FORCE_EVAL(x + 0x1p120f);
			return 1;
		}
		t = expm1f(x);
		return 1 + t*t/(2*(1+t));
	}

	/* |x| < log(FLT_MAX) */
	if (w < 0x42b17217) {
		t = expf(x);
		return 0.5f*(t + 1/t);
	}

	/* |x| > log(FLT_MAX) or nan */
	t = __expo2f(x);
	return t;
}
