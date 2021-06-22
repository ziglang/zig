#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double nearbyint(double x)
{
	__asm__ ("fidbra %0, 0, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../nearbyint.c"

#endif
