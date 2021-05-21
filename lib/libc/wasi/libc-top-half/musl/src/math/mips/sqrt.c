#if !defined(__mips_soft_float) && __mips >= 3

#include <math.h>

double sqrt(double x)
{
	double r;
	__asm__("sqrt.d %0,%1" : "=f"(r) : "f"(x));
	return r;
}

#else

#include "../sqrt.c"

#endif
