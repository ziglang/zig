#include "libm.h"

/* atanh(x) = log((1+x)/(1-x))/2 = log1p(2x/(1-x))/2 ~= x + x^3/3 + o(x^5) */
float atanhf(float x)
{
	union {float f; uint32_t i;} u = {.f = x};
	unsigned s = u.i >> 31;
	float_t y;

	/* |x| */
	u.i &= 0x7fffffff;
	y = u.f;

	if (u.i < 0x3f800000 - (1<<23)) {
		if (u.i < 0x3f800000 - (32<<23)) {
			/* handle underflow */
			if (u.i < (1<<23))
				FORCE_EVAL((float)(y*y));
		} else {
			/* |x| < 0.5, up to 1.7ulp error */
			y = 0.5f*log1pf(2*y + 2*y*y/(1-y));
		}
	} else {
		/* avoid overflow */
		y = 0.5f*log1pf(2*(y/(1-y)));
	}
	return s ? -y : y;
}
