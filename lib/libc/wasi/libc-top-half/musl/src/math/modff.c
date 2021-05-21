#include "libm.h"

float modff(float x, float *iptr)
{
	union {float f; uint32_t i;} u = {x};
	uint32_t mask;
	int e = (int)(u.i>>23 & 0xff) - 0x7f;

	/* no fractional part */
	if (e >= 23) {
		*iptr = x;
		if (e == 0x80 && u.i<<9 != 0) { /* nan */
			return x;
		}
		u.i &= 0x80000000;
		return u.f;
	}
	/* no integral part */
	if (e < 0) {
		u.i &= 0x80000000;
		*iptr = u.f;
		return x;
	}

	mask = 0x007fffff>>e;
	if ((u.i & mask) == 0) {
		*iptr = x;
		u.i &= 0x80000000;
		return u.f;
	}
	u.i &= ~mask;
	*iptr = u.f;
	return x - u.f;
}
