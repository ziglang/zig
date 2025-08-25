#include "complex_impl.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double complex casinhl(long double complex z)
{
	return casinh(z);
}
#else
long double complex casinhl(long double complex z)
{
	z = casinl(CMPLXL(-cimagl(z), creall(z)));
	return CMPLXL(cimagl(z), -creall(z));
}
#endif
