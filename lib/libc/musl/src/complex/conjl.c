#include "libm.h"

long double complex conjl(long double complex z)
{
	return CMPLXL(creall(z), -cimagl(z));
}
