#include "libm.h"

// FIXME: Hull et al. "Implementing the complex arcsine and arccosine functions using exception handling" 1997

/* acos(z) = pi/2 - asin(z) */

double complex cacos(double complex z)
{
	z = casin(z);
	return CMPLX(M_PI_2 - creal(z), -cimag(z));
}
