#include "libm.h"

/* atanh = -i atan(i z) */

double complex catanh(double complex z)
{
	z = catan(CMPLX(-cimag(z), creal(z)));
	return CMPLX(cimag(z), -creal(z));
}
