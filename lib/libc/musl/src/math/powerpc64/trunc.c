#include <math.h>

#ifdef _ARCH_PWR5X

double trunc(double x)
{
	__asm__ ("friz %0, %1" : "=d"(x) : "d"(x));
	return x;
}

#else

#include "../trunc.c"

#endif
