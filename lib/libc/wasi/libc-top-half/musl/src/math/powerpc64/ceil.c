#include <math.h>

#ifdef _ARCH_PWR5X

double ceil(double x)
{
	__asm__ ("frip %0, %1" : "=d"(x) : "d"(x));
	return x;
}

#else

#include "../ceil.c"

#endif
