#include "complex_impl.h"

long double complex conjl(long double complex z)
{
	return CMPLXL(creall(z), -cimagl(z));
}
