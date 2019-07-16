#include "complex_impl.h"

/* asinh(z) = -i asin(i z) */

double complex casinh(double complex z)
{
	z = casin(CMPLX(-cimag(z), creal(z)));
	return CMPLX(cimag(z), -creal(z));
}
