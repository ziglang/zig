#include <math.h>

#if !defined _SOFT_FLOAT && defined _ARCH_PPCSQ

double sqrt(double x)
{
	__asm__ ("fsqrt %0, %1\n" : "=d" (x) : "d" (x));
	return x;
}

#else

#include "../sqrt.c"

#endif
