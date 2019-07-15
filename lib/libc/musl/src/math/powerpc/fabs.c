#include <math.h>

#ifdef _SOFT_FLOAT

#include "../fabs.c"

#else

double fabs(double x)
{
	__asm__ ("fabs %0, %1" : "=d"(x) : "d"(x));
	return x;
}

#endif
