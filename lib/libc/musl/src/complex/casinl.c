#include "complex_impl.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double complex casinl(long double complex z)
{
	return casin(z);
}
#else
// FIXME
long double complex casinl(long double complex z)
{
	long double complex w;
	long double x, y;

	x = creall(z);
	y = cimagl(z);
	w = CMPLXL(1.0 - (x - y)*(x + y), -2.0*x*y);
	long double complex r = clogl(CMPLXL(-y, x) + csqrtl(w));
	return CMPLXL(cimagl(r), -creall(r));
}
#endif
