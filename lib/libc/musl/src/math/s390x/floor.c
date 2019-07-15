#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double floor(double x)
{
	__asm__ ("fidbra %0, 7, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../floor.c"

#endif
