#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double trunc(double x)
{
	__asm__ ("fidbra %0, 5, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../trunc.c"

#endif
