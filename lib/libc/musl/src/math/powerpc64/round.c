#include <math.h>

#ifdef _ARCH_PWR5X

double round(double x)
{
	__asm__ ("frin %0, %1" : "=d"(x) : "d"(x));
	return x;
}

#else

#include "../round.c"

#endif
