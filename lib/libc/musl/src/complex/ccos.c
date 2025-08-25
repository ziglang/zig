#include "complex_impl.h"

/* cos(z) = cosh(i z) */

double complex ccos(double complex z)
{
	return ccosh(CMPLX(-cimag(z), creal(z)));
}
