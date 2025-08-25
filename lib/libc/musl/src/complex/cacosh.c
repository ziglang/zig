#include "complex_impl.h"

/* acosh(z) = i acos(z) */

double complex cacosh(double complex z)
{
	int zineg = signbit(cimag(z));

	z = cacos(z);
	if (zineg) return CMPLX(cimag(z), -creal(z));
	else       return CMPLX(-cimag(z), creal(z));
}
