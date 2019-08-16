#include "complex_impl.h"

double cabs(double complex z)
{
	return hypot(creal(z), cimag(z));
}
