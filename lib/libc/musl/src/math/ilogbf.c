#include <limits.h>
#include "libm.h"

int ilogbf(float x)
{
	#pragma STDC FENV_ACCESS ON
	union {float f; uint32_t i;} u = {x};
	uint32_t i = u.i;
	int e = i>>23 & 0xff;

	if (!e) {
		i <<= 9;
		if (i == 0) {
			FORCE_EVAL(0/0.0f);
			return FP_ILOGB0;
		}
		/* subnormal x */
		for (e = -0x7f; i>>31 == 0; e--, i<<=1);
		return e;
	}
	if (e == 0xff) {
		FORCE_EVAL(0/0.0f);
		return i<<9 ? FP_ILOGBNAN : INT_MAX;
	}
	return e - 0x7f;
}
