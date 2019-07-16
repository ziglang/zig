#include "libm.h"

/* tan(z) = -i tanh(i z) */

double complex ctan(double complex z)
{
	z = ctanh(CMPLX(-cimag(z), creal(z)));
	return CMPLX(cimag(z), -creal(z));
}
