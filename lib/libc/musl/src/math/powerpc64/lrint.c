#include <math.h>

#ifdef _ARCH_PWR5X

long lrint(double x)
{
	long n;
	__asm__ ("fctid %0, %1" : "=d"(n) : "d"(x));
	return n;
}

#else

#include "../lrint.c"

#endif
