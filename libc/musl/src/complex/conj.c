#include "libm.h"

double complex conj(double complex z)
{
	return CMPLX(creal(z), -cimag(z));
}
