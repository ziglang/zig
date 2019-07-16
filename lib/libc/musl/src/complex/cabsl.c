#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double cabsl(long double complex z)
{
	return cabs(z);
}
#else
long double cabsl(long double complex z)
{
	return hypotl(creall(z), cimagl(z));
}
#endif
