#if !defined(__mips_soft_float) && defined(__mips_abs2008)

#include <math.h>

double fabs(double x)
{
	double r;
	__asm__("abs.d %0,%1" : "=f"(r) : "f"(x));
	return r;
}

#else

#include "../fabs.c"

#endif
