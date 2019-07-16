#include "libm.h"

float complex conjf(float complex z)
{
	return CMPLXF(crealf(z), -cimagf(z));
}
