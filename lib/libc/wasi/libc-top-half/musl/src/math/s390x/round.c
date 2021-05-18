#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double round(double x)
{
	__asm__ ("fidbra %0, 1, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../round.c"

#endif
