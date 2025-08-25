#include "complex_impl.h"

float complex cprojf(float complex z)
{
	if (isinf(crealf(z)) || isinf(cimagf(z)))
		return CMPLXF(INFINITY, copysignf(0.0, cimagf(z)));
	return z;
}
