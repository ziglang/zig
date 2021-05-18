#include "complex_impl.h"

float cabsf(float complex z)
{
	return hypotf(crealf(z), cimagf(z));
}
