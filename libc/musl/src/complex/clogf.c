#include "libm.h"

// FIXME

float complex clogf(float complex z)
{
	float r, phi;

	r = cabsf(z);
	phi = cargf(z);
	return CMPLXF(logf(r), phi);
}
