#include "complex_impl.h"

// FIXME

/* asin(z) = -i log(i z + sqrt(1 - z*z)) */

double complex casin(double complex z)
{
	double complex w;
	double x, y;

	x = creal(z);
	y = cimag(z);
	w = CMPLX(1.0 - (x - y)*(x + y), -2.0*x*y);
	double complex r = clog(CMPLX(-y, x) + csqrt(w));
	return CMPLX(cimag(r), -creal(r));
}
