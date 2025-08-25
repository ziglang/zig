#include "complex_impl.h"

double complex cproj(double complex z)
{
	if (isinf(creal(z)) || isinf(cimag(z)))
		return CMPLX(INFINITY, copysign(0.0, cimag(z)));
	return z;
}
